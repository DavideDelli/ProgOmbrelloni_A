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
import java.time.LocalDate;

@WebServlet("/profilo")
public class ProfiloServlet extends HttpServlet {

    private TemplateEngine templateEngine;

    @Override
    public void init() throws ServletException {
        this.templateEngine = (TemplateEngine) getServletContext().getAttribute(ThymeleafListener.TEMPLATE_ENGINE_ATTR);
    }

    // Mostra la pagina
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        response.setContentType("text/html;charset=UTF-8");

        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("codice_cliente") == null) {
            response.sendRedirect(request.getContextPath() + "/accesso");
            return;
        }

        WebContext ctx = new WebContext(request, response, getServletContext(), request.getLocale());

        // Recuperiamo eventuali messaggi di successo o errore dalla sessione
        ctx.setVariable("messaggioSuccesso", session.getAttribute("messaggioSuccesso"));
        ctx.setVariable("messaggioErrore", session.getAttribute("messaggioErrore"));
        session.removeAttribute("messaggioSuccesso");
        session.removeAttribute("messaggioErrore");

        ctx.setVariable("nomeCliente", session.getAttribute("nome_cliente"));
        ctx.setVariable("cognomeCliente", session.getAttribute("cognome_cliente"));
        ctx.setVariable("dataNascita", session.getAttribute("dataNascita_cliente"));
        ctx.setVariable("codiceCliente", session.getAttribute("codice_cliente"));

        templateEngine.process("profilo", ctx, response.getWriter());
    }

    // Salva le modifiche
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        request.setCharacterEncoding("UTF-8");
        HttpSession session = request.getSession(false);

        if (session == null || session.getAttribute("codice_cliente") == null) {
            response.sendRedirect(request.getContextPath() + "/accesso");
            return;
        }

        String codiceCliente = (String) session.getAttribute("codice_cliente");
        String nome = request.getParameter("nome");
        String cognome = request.getParameter("cognome");
        String dataNascita = request.getParameter("dataNascita");

        try {
            LocalDate nascita = LocalDate.parse(dataNascita);
            if (nascita.isAfter(LocalDate.now())) {
                session.setAttribute("messaggioErrore", "La data di nascita non può essere nel futuro.");
                response.sendRedirect(request.getContextPath() + "/profilo");
                return;
            }

            try (Connection conn = DatabaseManager.getInstance().getConnection()) {
                String sql = "UPDATE cliente SET nome = ?, cognome = ?, dataNascita = ? WHERE codice = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sql)) {
                    stmt.setString(1, nome);
                    stmt.setString(2, cognome);
                    stmt.setString(3, dataNascita);
                    stmt.setString(4, codiceCliente);
                    stmt.executeUpdate();
                }

                // Aggiorniamo i dati salvati in RAM nella sessione attuale
                session.setAttribute("nome_cliente", nome);
                session.setAttribute("cognome_cliente", cognome);
                session.setAttribute("dataNascita_cliente", dataNascita);

                session.setAttribute("messaggioSuccesso", "Profilo aggiornato con successo!");
            }
        } catch (Exception e) {
            session.setAttribute("messaggioErrore", "Errore durante l'aggiornamento: " + e.getMessage());
        }

        // Dopo il salvataggio, ricarichiamo la pagina Profilo
        response.sendRedirect(request.getContextPath() + "/profilo");
    }
}