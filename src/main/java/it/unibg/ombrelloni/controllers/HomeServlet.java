package it.unibg.ombrelloni.controllers;

import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.WebContext;
import it.unibg.ombrelloni.config.ThymeleafListener;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

// Mappiamo la servlet sulla root del sito e su /index.php per retrocompatibilità
@WebServlet(urlPatterns = {"/", "/index.php"})
public class HomeServlet extends HttpServlet {

    private TemplateEngine templateEngine;

    @Override
    public void init() throws ServletException {
        // Recupera il motore di Thymeleaf inizializzato dal Listener
        this.templateEngine = (TemplateEngine) getServletContext().getAttribute(ThymeleafListener.TEMPLATE_ENGINE_ATTR);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        response.setContentType("text/html;charset=UTF-8");

        // Crea il contesto di Thymeleaf (passa dati dalla Servlet all'HTML)
        WebContext ctx = new WebContext(request, response, getServletContext(), request.getLocale());
        
        // Passiamo un attributo di test alla pagina
        ctx.setVariable("titoloProgetto", "Lido Codici Sballati - Versione Java");

        // Renderizza il file index.html
        templateEngine.process("index", ctx, response.getWriter());
    }
}