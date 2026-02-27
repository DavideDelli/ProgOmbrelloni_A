package it.unibg.ombrelloni.controllers;

import it.unibg.ombrelloni.config.DatabaseManager;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;

@WebServlet("/elimina_prenotazione")
public class EliminaPrenotazioneServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("codice_cliente") == null) {
            response.sendRedirect(request.getContextPath() + "/accesso");
            return;
        }

        String codiceCliente = (String) session.getAttribute("codice_cliente");
        String numContratto = request.getParameter("num_contratto");

        if (numContratto != null) {
            try (Connection conn = DatabaseManager.getInstance().getConnection()) {
                conn.setAutoCommit(false);
                try {
                    // 1. Sgancia i giorni prenotati (li fa tornare disponibili sulla mappa)
                    String sqlRelease = "UPDATE giornodisponibilita SET numProgrContratto = NULL WHERE numProgrContratto = ? AND numProgrContratto IN (SELECT numProgr FROM contratto WHERE codiceCliente = ?)";
                    try (PreparedStatement stmtRelease = conn.prepareStatement(sqlRelease)) {
                        stmtRelease.setInt(1, Integer.parseInt(numContratto));
                        stmtRelease.setString(2, codiceCliente);
                        stmtRelease.executeUpdate();
                    }

                    // 2. Elimina fisicamente il contratto
                    String sqlDelete = "DELETE FROM contratto WHERE numProgr = ? AND codiceCliente = ?";
                    try (PreparedStatement stmtDelete = conn.prepareStatement(sqlDelete)) {
                        stmtDelete.setInt(1, Integer.parseInt(numContratto));
                        stmtDelete.setString(2, codiceCliente);
                        stmtDelete.executeUpdate();
                    }

                    conn.commit();
                    session.setAttribute("messaggioSuccesso", "Prenotazione #" + numContratto + " annullata con successo.");
                } catch (Exception e) {
                    conn.rollback();
                    session.setAttribute("messaggioErrore", "Errore durante l'annullamento della prenotazione.");
                } finally {
                    conn.setAutoCommit(true);
                }
            } catch (Exception e) {
                session.setAttribute("messaggioErrore", "Errore di connessione al database.");
            }
        }
        response.sendRedirect(request.getContextPath() + "/le_mie_prenotazioni");
    }
}