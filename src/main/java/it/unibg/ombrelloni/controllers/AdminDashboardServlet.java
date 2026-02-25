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

@WebServlet("/admin/dashboard")
public class AdminDashboardServlet extends HttpServlet {

    private TemplateEngine templateEngine;

    @Override
    public void init() throws ServletException {
        this.templateEngine = (TemplateEngine) getServletContext().getAttribute(ThymeleafListener.TEMPLATE_ENGINE_ATTR);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        response.setContentType("text/html;charset=UTF-8");

        HttpSession session = request.getSession(false);
        // Se non sei loggato come admin, ti rimando al nuovo percorso auth
        if (session == null || session.getAttribute("admin_logged_in") == null) {
            response.sendRedirect(request.getContextPath() + "/auth/admin_login");
            return;
        }

        WebContext ctx = new WebContext(request, response, getServletContext(), request.getLocale());
        templateEngine.process("admin/dashboard", ctx, response.getWriter());
    }
}