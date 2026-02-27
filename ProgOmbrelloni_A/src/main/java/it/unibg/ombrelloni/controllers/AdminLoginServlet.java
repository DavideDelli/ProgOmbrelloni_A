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

@WebServlet("/auth/admin_login")
public class AdminLoginServlet extends HttpServlet {

    private TemplateEngine templateEngine;

    @Override
    public void init() throws ServletException {
        this.templateEngine = (TemplateEngine) getServletContext().getAttribute(ThymeleafListener.TEMPLATE_ENGINE_ATTR);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        response.setContentType("text/html;charset=UTF-8");
        WebContext ctx = new WebContext(request, response, getServletContext(), request.getLocale());

        ctx.setVariable("errore", request.getParameter("errore") != null);
        templateEngine.process("admin/login", ctx, response.getWriter());
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String password = request.getParameter("password");

        if ("admin123".equals(password)) {
            HttpSession session = request.getSession(true);
            session.setAttribute("admin_logged_in", true);
            // Se la password è corretta, vai alla dashboard!
            response.sendRedirect(request.getContextPath() + "/admin/dashboard");
        } else {
            // Se è errata, rimani nel login con errore
            response.sendRedirect(request.getContextPath() + "/auth/admin_login?errore=1");
        }
    }
}