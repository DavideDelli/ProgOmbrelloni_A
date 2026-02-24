package it.unibg.ombrelloni.controllers;

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

        // Controllo di sicurezza: devi essere loggato
        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("codice_cliente") == null) {
            response.sendRedirect(request.getContextPath() + "/accesso");
            return;
        }

        // Recuperiamo i dati dall'URL cliccato sulla mappa
        String idOmbrellone = request.getParameter("id");
        String dataSelezionata = request.getParameter("data");
        String tipoPrenotazione = request.getParameter("tipo");

        // Se manca qualcosa, rimandiamo alla mappa
        if (idOmbrellone == null || dataSelezionata == null || tipoPrenotazione == null) {
            response.sendRedirect(request.getContextPath() + "/mappa");
            return;
        }

        WebContext ctx = new WebContext(request, response, getServletContext(), request.getLocale());

        // Passiamo i dati alla pagina di riepilogo
        ctx.setVariable("idOmbrellone", idOmbrellone);
        ctx.setVariable("dataSelezionata", dataSelezionata);
        ctx.setVariable("tipoPrenotazione", tipoPrenotazione);
        ctx.setVariable("nomeCliente", session.getAttribute("nome_cliente"));

        // Renderizziamo la vista
        templateEngine.process("conferma", ctx, response.getWriter());
    }
}