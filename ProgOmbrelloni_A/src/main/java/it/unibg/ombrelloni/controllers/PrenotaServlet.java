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
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@WebServlet("/prenota")
public class PrenotaServlet extends HttpServlet {

    private TemplateEngine templateEngine;

    @Override
    public void init() throws ServletException {
        this.templateEngine = (TemplateEngine) getServletContext().getAttribute(ThymeleafListener.TEMPLATE_ENGINE_ATTR);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        response.setContentType("text/html;charset=UTF-8");

        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("codice_cliente") == null) {
            response.sendRedirect(request.getContextPath() + "/accesso");
            return;
        }

        String idOmbrelloneStr = request.getParameter("id");
        String dataSelezionata = request.getParameter("data");
        String tipoPrenotazione = request.getParameter("tipo");

        if (idOmbrelloneStr == null || dataSelezionata == null || tipoPrenotazione == null) {
            response.sendRedirect(request.getContextPath() + "/mappa");
            return;
        }

        int idOmbrellone = Integer.parseInt(idOmbrelloneStr);
        String errore = "";
        Map<String, Object> ombrelloneInfo = new HashMap<>();
        List<Map<String, Object>> tariffeDisponibili = new ArrayList<>();

        try (Connection conn = DatabaseManager.getInstance().getConnection()) {
            // 1. Dettagli Ombrellone (replicando la query di prenota.php) [cite: 424, 425]
            String sqlOmbrellone = "SELECT o.id, o.settore, o.numFila, o.numPostoFila, t.codice AS cod_tipologia " +
                    "FROM ombrellone o JOIN tipologia t ON o.codTipologia = t.codice " +
                    "WHERE o.id = ?";
            try (PreparedStatement stmtOmb = conn.prepareStatement(sqlOmbrellone)) {
                stmtOmb.setInt(1, idOmbrellone);
                try (ResultSet rsOmb = stmtOmb.executeQuery()) {
                    if (rsOmb.next()) {
                        ombrelloneInfo.put("id", rsOmb.getInt("id"));
                        ombrelloneInfo.put("settore", rsOmb.getString("settore"));
                        ombrelloneInfo.put("numFila", rsOmb.getInt("numFila"));
                        ombrelloneInfo.put("numPostoFila", rsOmb.getInt("numPostoFila"));
                        ombrelloneInfo.put("cod_tipologia", rsOmb.getString("cod_tipologia"));

                        // 2. Recupero Tariffe associate alla tipologia (replicando la query) [cite: 427, 428]
                        String tipoTariffaDb = "settimanale".equals(tipoPrenotazione) ? "SETTIMANALE" : "GIORNALIERO";
                        String sqlTariffe = "SELECT tar.codice, tar.prezzo, tar.descrizione " +
                                "FROM tariffa tar JOIN tipologiatariffa tt ON tar.codice = tt.codTariffa " +
                                "WHERE tt.codTipologia = ? AND tar.tipo = ? ORDER BY tar.prezzo ASC";
                        try (PreparedStatement stmtTar = conn.prepareStatement(sqlTariffe)) {
                            stmtTar.setString(1, rsOmb.getString("cod_tipologia"));
                            stmtTar.setString(2, tipoTariffaDb);
                            try (ResultSet rsTar = stmtTar.executeQuery()) {
                                while (rsTar.next()) {
                                    Map<String, Object> tariffa = new HashMap<>();
                                    tariffa.put("codice", rsTar.getString("codice"));
                                    tariffa.put("prezzo", rsTar.getDouble("prezzo"));
                                    tariffa.put("descrizione", rsTar.getString("descrizione"));
                                    tariffeDisponibili.add(tariffa);
                                }
                            }
                        }
                    } else {
                        errore = "Ombrellone non trovato nel database.";
                    }
                }
            }
        } catch (SQLException e) {
            errore = "Errore di connessione al database: " + e.getMessage();
        }

        if (tariffeDisponibili.isEmpty() && errore.isEmpty()) {
            errore = "Nessuna tariffa configurata per questa tipologia di ombrellone.";
        }

        WebContext ctx = new WebContext(request, response, getServletContext(), request.getLocale());
        ctx.setVariable("errore", errore);
        ctx.setVariable("idOmbrellone", idOmbrelloneStr);
        ctx.setVariable("dataSelezionata", dataSelezionata);
        ctx.setVariable("tipoPrenotazione", tipoPrenotazione);
        ctx.setVariable("nomeCliente", session.getAttribute("nome_cliente"));
        ctx.setVariable("cognomeCliente", session.getAttribute("cognome_cliente"));
        ctx.setVariable("ombrellone", ombrelloneInfo);
        ctx.setVariable("tariffe", tariffeDisponibili);

        templateEngine.process("conferma", ctx, response.getWriter());
    }
}