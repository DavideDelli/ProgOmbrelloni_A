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

@WebServlet("/elimina_account")
public class EliminaAccountServlet extends HttpServlet {

    private TemplateEngine templateEngine;

    @Override
    public void init() throws ServletException {
        this.templateEngine = (TemplateEngine) getServletContext().getAttribute(ThymeleafListener.TEMPLATE_ENGINE_ATTR);
    }

    // Mostra la schermata di conferma
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        response.setContentType("text/html;charset=UTF-8");
        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("codice_cliente") == null) {
            response.sendRedirect(request.getContextPath() + "/accesso");
            return;
        }

        WebContext ctx = new WebContext(request, response, getServletContext(), request.getLocale());
        ctx.setVariable("nomeCliente", session.getAttribute("nome_cliente"));
        ctx.setVariable("codiceCliente", session.getAttribute("codice_cliente"));
        templateEngine.process("elimina_account", ctx, response.getWriter());
    }

    // Esegue l'eliminazione effettiva dal DB
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("codice_cliente") == null) {
            response.sendRedirect(request.getContextPath() + "/accesso");
            return;
        }

        String codiceCliente = (String) session.getAttribute("codice_cliente");

        try (Connection conn = DatabaseManager.getInstance().getConnection()) {
            conn.setAutoCommit(false);
            try {
                // 1. Sgancia i giorni prenotati (rimuove il riferimento ai contratti dell'utente)
                String sqlRelease = "UPDATE giornodisponibilita SET numProgrContratto = NULL WHERE numProgrContratto IN (SELECT numProgr FROM contratto WHERE codiceCliente = ?)";
                try (PreparedStatement stmtRelease = conn.prepareStatement(sqlRelease)) {
                    stmtRelease.setString(1, codiceCliente);
                    stmtRelease.executeUpdate();
                }

                // 2. Elimina i contratti
                String sqlDeleteContracts = "DELETE FROM contratto WHERE codiceCliente = ?";
                try (PreparedStatement stmtContracts = conn.prepareStatement(sqlDeleteContracts)) {
                    stmtContracts.setString(1, codiceCliente);
                    stmtContracts.executeUpdate();
                }

                // 3. Elimina il cliente
                String sqlDeleteClient = "DELETE FROM cliente WHERE codice = ?";
                try (PreparedStatement stmtClient = conn.prepareStatement(sqlDeleteClient)) {
                    stmtClient.setString(1, codiceCliente);
                    stmtClient.executeUpdate();
                }

                conn.commit();

                // Distruggi la sessione per disconnettere l'utente
                session.invalidate();

                // Reindirizza alla pagina di addio
                response.sendRedirect(request.getContextPath() + "/account_eliminato");
                return;

            } catch (Exception e) {
                conn.rollback();
                session.setAttribute("messaggioErrore", "Errore durante l'eliminazione: " + e.getMessage());
                response.sendRedirect(request.getContextPath() + "/profilo");
                return;
            } finally {
                conn.setAutoCommit(true);
            }
        } catch (Exception e) {
            session.setAttribute("messaggioErrore", "Errore di connessione al database.");
            response.sendRedirect(request.getContextPath() + "/profilo");
        }
    }
}