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

// Mappiamo questa Servlet per gestire tutte le pagine visive della sezione auth
@WebServlet(urlPatterns = {"/accesso", "/registrazione", "/recupero_codice"})
public class AuthServlet extends HttpServlet {

    private TemplateEngine templateEngine;

    @Override
    public void init() throws ServletException {
        this.templateEngine = (TemplateEngine) getServletContext().getAttribute(ThymeleafListener.TEMPLATE_ENGINE_ATTR);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        response.setContentType("text/html;charset=UTF-8");
        WebContext ctx = new WebContext(request, response, getServletContext(), request.getLocale());

        String path = request.getServletPath();
        String templateName = "";

        // A seconda dell'URL richiesto, carichiamo il file HTML corrispondente
        if (path.equals("/accesso")) {
            templateName = "auth/accesso";
        } else if (path.equals("/registrazione")) {
            templateName = "auth/registrazione"; // Lo faremo in seguito
        } else if (path.equals("/recupero_codice")) {
            templateName = "auth/recupero_codice"; // Lo faremo in seguito
        }

        templateEngine.process(templateName, ctx, response.getWriter());
    }
}