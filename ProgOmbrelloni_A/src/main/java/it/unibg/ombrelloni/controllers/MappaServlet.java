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

@WebServlet("/mappa")
public class MappaServlet extends HttpServlet {

    private TemplateEngine templateEngine;

    @Override
    public void init() throws ServletException {
        this.templateEngine = (TemplateEngine) getServletContext().getAttribute(ThymeleafListener.TEMPLATE_ENGINE_ATTR);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        response.setContentType("text/html;charset=UTF-8");

        // Controllo: se non sei loggato, torni al login
        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("codice_cliente") == null) {
            response.sendRedirect(request.getContextPath() + "/accesso");
            return;
        }

        WebContext ctx = new WebContext(request, response, getServletContext(), request.getLocale());

        String tipoPrenotazione = request.getParameter("tipo_prenotazione");
        if (tipoPrenotazione == null) tipoPrenotazione = "giornaliero";

        String dataSelezionata = request.getParameter("data_ricerca");
        if (dataSelezionata == null || dataSelezionata.trim().isEmpty()) {
            dataSelezionata = "2026-06-01"; // Data base
        }

        // --- FIX CRASH 500 ---
        try {
            java.sql.Date.valueOf(dataSelezionata);
        } catch (IllegalArgumentException e) {
            // Se l'utente digita una data incompleta, impostiamo la data di default
            dataSelezionata = "2026-06-01";
        }

        List<Map<String, Object>> ombrelloniMappa = new ArrayList<>();
        String messaggioErrore = "";

        try (Connection conn = DatabaseManager.getInstance().getConnection()) {
            String sqlCheck = "SELECT 1 FROM giornodisponibilita WHERE data = ? LIMIT 1";
            try (PreparedStatement stmtCheck = conn.prepareStatement(sqlCheck)) {
                stmtCheck.setDate(1, java.sql.Date.valueOf(dataSelezionata));
                try (ResultSet rsCheck = stmtCheck.executeQuery()) {

                    if (rsCheck.next()) {
                        if ("settimanale".equals(tipoPrenotazione)) {
                            String dataFine = java.time.LocalDate.parse(dataSelezionata).plusDays(6).toString();
                            String sqlOccupati = "SELECT DISTINCT idOmbrellone FROM giornodisponibilita WHERE data BETWEEN ? AND ? AND numProgrContratto IS NOT NULL";

                            List<Integer> idOccupati = new ArrayList<>();
                            try (PreparedStatement stmtOcc = conn.prepareStatement(sqlOccupati)) {
                                stmtOcc.setDate(1, java.sql.Date.valueOf(dataSelezionata));
                                stmtOcc.setDate(2, java.sql.Date.valueOf(dataFine));
                                ResultSet rsOcc = stmtOcc.executeQuery();
                                while (rsOcc.next()) idOccupati.add(rsOcc.getInt("idOmbrellone"));
                            }

                            String sqlOmbrelloni = "SELECT id, settore, numFila, numPostoFila, codTipologia FROM ombrellone";
                            try (PreparedStatement stmtOmb = conn.prepareStatement(sqlOmbrelloni);
                                 ResultSet rsOmb = stmtOmb.executeQuery()) {
                                while (rsOmb.next()) {
                                    Map<String, Object> omb = popolaOmbrellone(rsOmb);
                                    omb.put("occupato", idOccupati.contains((Integer) omb.get("id")));
                                    ombrelloniMappa.add(omb);
                                }
                            }
                        } else {
                            String sqlGiornaliero = "SELECT o.id, o.settore, o.numFila, o.numPostoFila, o.codTipologia, " +
                                    "CASE WHEN gd.numProgrContratto IS NOT NULL THEN 1 ELSE 0 END AS occupato " +
                                    "FROM ombrellone o LEFT JOIN giornodisponibilita gd ON o.id = gd.idOmbrellone AND gd.data = ? " +
                                    "ORDER BY o.settore, o.numFila, o.numPostoFila";

                            try (PreparedStatement stmtGiorn = conn.prepareStatement(sqlGiornaliero)) {
                                stmtGiorn.setDate(1, java.sql.Date.valueOf(dataSelezionata));
                                ResultSet rsGiorn = stmtGiorn.executeQuery();
                                while (rsGiorn.next()) {
                                    Map<String, Object> omb = popolaOmbrellone(rsGiorn);
                                    omb.put("occupato", rsGiorn.getInt("occupato") == 1);
                                    ombrelloniMappa.add(omb);
                                }
                            }
                        }
                    } else {
                        messaggioErrore = "La data selezionata non è disponibile. Scegli un'altra data.";
                    }
                }
            }
        } catch (SQLException e) {
            messaggioErrore = "Errore di connessione al DB.";
        }

        ctx.setVariable("dataSelezionata", dataSelezionata);
        ctx.setVariable("tipoPrenotazione", tipoPrenotazione);
        ctx.setVariable("messaggioErrore", messaggioErrore);
        ctx.setVariable("ombrelloni", ombrelloniMappa);
        ctx.setVariable("nomeCliente", session.getAttribute("nome_cliente"));
        templateEngine.process("mappa", ctx, response.getWriter());
    }

    private Map<String, Object> popolaOmbrellone(ResultSet rs) throws SQLException {
        Map<String, Object> map = new HashMap<>();
        map.put("id", rs.getInt("id"));
        map.put("settore", rs.getString("settore"));
        map.put("numFila", rs.getInt("numFila"));
        map.put("numPostoFila", rs.getInt("numPostoFila"));
        map.put("codTipologia", rs.getString("codTipologia"));
        return map;
    }
}