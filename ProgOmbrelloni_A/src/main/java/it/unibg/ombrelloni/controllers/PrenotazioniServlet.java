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

@WebServlet("/le_mie_prenotazioni")
public class PrenotazioniServlet extends HttpServlet {

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

        String codiceCliente = (String) session.getAttribute("codice_cliente");
        List<Map<String, Object>> prenotazioni = new ArrayList<>();
        String messaggioErrore = "";

        // Recupera eventuali messaggi dalle operazioni di eliminazione
        String messaggioSuccesso = (String) session.getAttribute("messaggioSuccesso");
        session.removeAttribute("messaggioSuccesso");

        if (session.getAttribute("messaggioErrore") != null) {
            messaggioErrore = (String) session.getAttribute("messaggioErrore");
            session.removeAttribute("messaggioErrore");
        }

        try (Connection conn = DatabaseManager.getInstance().getConnection()) {
            // Aggiungiamo la JOIN con 'tariffa' per recuperare la descrizione esatta del pacchetto
            String sql = "SELECT c.numProgr, c.data, c.dataFine, c.importo, o.settore, o.numFila, o.numPostoFila, o.codTipologia, t.descrizione AS nome_tariffa " +
                    "FROM contratto c " +
                    "JOIN giornodisponibilita gd ON c.numProgr = gd.numProgrContratto " +
                    "JOIN ombrellone o ON gd.idOmbrellone = o.id " +
                    "LEFT JOIN tariffa t ON c.codTariffa = t.codice " +
                    "WHERE c.codiceCliente = ? " +
                    "GROUP BY c.numProgr, c.data, c.dataFine, c.importo, o.settore, o.numFila, o.numPostoFila, o.codTipologia, t.descrizione " +
                    "ORDER BY c.data DESC";

            try (PreparedStatement stmt = conn.prepareStatement(sql)) {
                stmt.setString(1, codiceCliente);
                try (ResultSet rs = stmt.executeQuery()) {
                    while (rs.next()) {
                        Map<String, Object> preno = new HashMap<>();
                        preno.put("numeroContratto", rs.getInt("numProgr"));
                        preno.put("dataInizio", rs.getDate("data"));
                        preno.put("dataFine", rs.getDate("dataFine"));
                        preno.put("importo", rs.getDouble("importo"));
                        preno.put("settore", rs.getString("settore"));
                        preno.put("fila", rs.getInt("numFila"));
                        preno.put("posto", rs.getInt("numPostoFila"));
                        preno.put("tipologia", rs.getString("codTipologia"));
                        // Ora peschiamo anche la tariffa!
                        preno.put("tariffa", rs.getString("nome_tariffa"));
                        prenotazioni.add(preno);
                    }
                }
            }
        } catch (SQLException e) {
            messaggioErrore = "Impossibile recuperare lo storico delle prenotazioni.";
            e.printStackTrace();
        }

        WebContext ctx = new WebContext(request, response, getServletContext(), request.getLocale());
        ctx.setVariable("prenotazioni", prenotazioni);
        ctx.setVariable("messaggioErrore", messaggioErrore);

        templateEngine.process("prenotazioni", ctx, response.getWriter());
    }
}