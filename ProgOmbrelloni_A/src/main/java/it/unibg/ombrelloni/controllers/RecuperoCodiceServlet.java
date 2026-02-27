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
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

@WebServlet("/auth/processa_recupero")
public class RecuperoCodiceServlet extends HttpServlet {

    private TemplateEngine templateEngine;

    @Override
    public void init() throws ServletException {
        this.templateEngine = (TemplateEngine) getServletContext().getAttribute(ThymeleafListener.TEMPLATE_ENGINE_ATTR);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        request.setCharacterEncoding("UTF-8");
        String nome = request.getParameter("nome");
        String cognome = request.getParameter("cognome");
        String dataNascita = request.getParameter("dataNascita");

        String codiceRecuperato = null;
        String errore = null;

        try (Connection conn = DatabaseManager.getInstance().getConnection()) {
            String sql = "SELECT codice FROM cliente WHERE nome = ? AND cognome = ? AND dataNascita = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sql)) {
                stmt.setString(1, nome);
                stmt.setString(2, cognome);
                stmt.setString(3, dataNascita);

                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        codiceRecuperato = rs.getString("codice");
                    } else {
                        errore = "Nessun cliente trovato con questi dati. Verifica di aver inserito i dati corretti.";
                    }
                }
            }
        } catch (Exception e) {
            errore = "Errore di connessione al database.";
        }

        WebContext ctx = new WebContext(request, response, getServletContext(), request.getLocale());
        ctx.setVariable("errore", errore);
        ctx.setVariable("codiceRecuperato", codiceRecuperato);
        templateEngine.process("auth/recupero_codice", ctx, response.getWriter());
    }
}