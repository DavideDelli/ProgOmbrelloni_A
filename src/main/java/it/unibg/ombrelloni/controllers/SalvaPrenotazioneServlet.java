package it.unibg.ombrelloni.controllers;

import it.unibg.ombrelloni.config.DatabaseManager;
import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.WebContext;
import it.unibg.ombrelloni.config.ThymeleafListener;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.*;
import java.time.LocalDate;

@WebServlet("/salva_prenotazione")
public class SalvaPrenotazioneServlet extends HttpServlet {

    private TemplateEngine templateEngine;

    @Override
    public void init() throws ServletException {
        this.templateEngine = (TemplateEngine) getServletContext().getAttribute(ThymeleafListener.TEMPLATE_ENGINE_ATTR);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        response.setContentType("text/html;charset=UTF-8");

        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("codice_cliente") == null) {
            response.sendRedirect(request.getContextPath() + "/accesso");
            return;
        }

        String codiceCliente = (String) session.getAttribute("codice_cliente");
        int idOmbrellone = Integer.parseInt(request.getParameter("id_ombrellone"));
        String dataInizioStr = request.getParameter("data_prenotazione");
        String tipoPrenotazione = request.getParameter("tipo_prenotazione");

        LocalDate dataInizio = LocalDate.parse(dataInizioStr);

        boolean successo = false;
        String messaggio = "";

        try (Connection conn = DatabaseManager.getInstance().getConnection()) {
            // Disabilitiamo l'autocommit per replicare il $pdo->beginTransaction()
            conn.setAutoCommit(false);

            try {
                // 1. Recupero dinamico della tariffa (Adattato per robustezza)
                String sqlPrezzo = "SELECT tar.codice, tar.prezzo FROM tariffa tar " +
                        "JOIN tipologiatariffa tt ON tar.codice = tt.codTariffa " +
                        "JOIN ombrellone o ON tt.codTipologia = o.codTipologia " +
                        "WHERE o.id = ? LIMIT 1";

                String codTariffa = "";
                double importoFinale = 0.0;

                try (PreparedStatement stmtPrezzo = conn.prepareStatement(sqlPrezzo)) {
                    stmtPrezzo.setInt(1, idOmbrellone);
                    try (ResultSet rs = stmtPrezzo.executeQuery()) {
                        if (rs.next()) {
                            codTariffa = rs.getString("codice");
                            importoFinale = rs.getDouble("prezzo");
                        } else {
                            throw new Exception("Nessuna tariffa valida per questo ombrellone.");
                        }
                    }
                }

                // Moltiplichiamo per 7 se è settimanale (Logica base)
                if ("settimanale".equals(tipoPrenotazione)) importoFinale *= 7;

                // 2. Controllo disponibilità per il settimanale
                LocalDate dataFineCalcolata = "settimanale".equals(tipoPrenotazione) ? dataInizio.plusDays(6) : dataInizio;

                if ("settimanale".equals(tipoPrenotazione)) {
                    String sqlCheck = "SELECT COUNT(*) FROM giornodisponibilita WHERE idOmbrellone = ? AND data BETWEEN ? AND ? AND numProgrContratto IS NOT NULL";
                    try (PreparedStatement stmtCheck = conn.prepareStatement(sqlCheck)) {
                        stmtCheck.setInt(1, idOmbrellone);
                        stmtCheck.setDate(2, java.sql.Date.valueOf(dataInizio));
                        stmtCheck.setDate(3, java.sql.Date.valueOf(dataFineCalcolata));
                        try (ResultSet rs = stmtCheck.executeQuery()) {
                            if (rs.next() && rs.getInt(1) > 0) {
                                throw new Exception("Impossibile completare: l'ombrellone è occupato per alcuni giorni del periodo.");
                            }
                        }
                    }
                }

                // 3. Inserimento Contratto
                Date sqlDataInizio = java.sql.Date.valueOf(dataInizio);
                Date sqlDataFine = "settimanale".equals(tipoPrenotazione) ? java.sql.Date.valueOf(dataFineCalcolata) : null;

                String sqlContratto = "INSERT INTO contratto (data, dataFine, importo, codiceCliente, codTariffa) VALUES (?, ?, ?, ?, ?)";
                int nuovoContrattoId = 0;
                try (PreparedStatement stmtContratto = conn.prepareStatement(sqlContratto, Statement.RETURN_GENERATED_KEYS)) {
                    stmtContratto.setDate(1, sqlDataInizio);
                    stmtContratto.setDate(2, sqlDataFine);
                    stmtContratto.setDouble(3, importoFinale);
                    stmtContratto.setString(4, codiceCliente);
                    stmtContratto.setString(5, codTariffa);
                    stmtContratto.executeUpdate();

                    try (ResultSet generatedKeys = stmtContratto.getGeneratedKeys()) {
                        if (generatedKeys.next()) nuovoContrattoId = generatedKeys.getInt(1);
                    }
                }

                // 4. Aggiornamento Giorni Disponibilità
                int giorniDaPrenotare = "settimanale".equals(tipoPrenotazione) ? 7 : 1;
                String sqlAggiorna = "UPDATE giornodisponibilita SET numProgrContratto = ? WHERE idOmbrellone = ? AND data = ? AND numProgrContratto IS NULL";

                try (PreparedStatement stmtAggiorna = conn.prepareStatement(sqlAggiorna)) {
                    for (int i = 0; i < giorniDaPrenotare; i++) {
                        LocalDate dataCorrente = dataInizio.plusDays(i);
                        stmtAggiorna.setInt(1, nuovoContrattoId);
                        stmtAggiorna.setInt(2, idOmbrellone);
                        stmtAggiorna.setDate(3, java.sql.Date.valueOf(dataCorrente));

                        int righeAggiornate = stmtAggiorna.executeUpdate();
                        if (righeAggiornate == 0) {
                            throw new Exception("Errore di concorrenza. Qualcuno ha prenotato mentre completavi l'operazione.");
                        }
                    }
                }

                // Se arriviamo qui, è andato tutto bene! Replicato il $pdo->commit()
                conn.commit();
                messaggio = "Prenotazione confermata con successo! Il tuo numero di contratto è " + nuovoContrattoId + ".";
                successo = true;

            } catch (Exception e) {
                conn.rollback(); // Se c'è un errore, annulla tutto
                messaggio = "Errore durante la prenotazione: " + e.getMessage();
            } finally {
                conn.setAutoCommit(true);
            }

        } catch (SQLException e) {
            messaggio = "Errore di connessione al database.";
        }

        // Passiamo le variabili alla pagina di esito
        WebContext ctx = new WebContext(request, response, getServletContext(), request.getLocale());
        ctx.setVariable("successo", successo);
        ctx.setVariable("messaggio", messaggio);
        templateEngine.process("esito_prenotazione", ctx, response.getWriter());
    }
}