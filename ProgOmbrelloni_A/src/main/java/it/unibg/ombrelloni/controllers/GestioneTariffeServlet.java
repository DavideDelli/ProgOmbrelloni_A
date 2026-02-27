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
import java.sql.*;
import java.util.*;

@WebServlet("/admin/gestione_tariffe")
public class GestioneTariffeServlet extends HttpServlet {
    private TemplateEngine templateEngine;

    @Override
    public void init() throws ServletException {
        this.templateEngine = (TemplateEngine) getServletContext().getAttribute(ThymeleafListener.TEMPLATE_ENGINE_ATTR);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        response.setContentType("text/html;charset=UTF-8");
        List<Map<String, Object>> tariffe = new ArrayList<>();
        try (Connection conn = DatabaseManager.getInstance().getConnection();
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery("SELECT * FROM tariffa")) {
            while (rs.next()) {
                Map<String, Object> t = new HashMap<>();
                t.put("codice", rs.getString("codice"));
                t.put("descrizione", rs.getString("descrizione"));
                t.put("prezzo", rs.getDouble("prezzo"));
                tariffe.add(t);
            }
        } catch (SQLException e) { throw new ServletException(e); }

        WebContext ctx = new WebContext(request, response, getServletContext(), request.getLocale());
        ctx.setVariable("tariffe", tariffe);
        templateEngine.process("admin/gestione_tariffe", ctx, response.getWriter());
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String codice = request.getParameter("codice");
        double nuovoPrezzo = Double.parseDouble(request.getParameter("prezzo"));

        try (Connection conn = DatabaseManager.getInstance().getConnection();
             PreparedStatement pst = conn.prepareStatement("UPDATE tariffa SET prezzo = ? WHERE codice = ?")) {
            pst.setDouble(1, nuovoPrezzo);
            pst.setString(2, codice);
            pst.executeUpdate();
            response.sendRedirect(request.getContextPath() + "/admin/gestione_tariffe");
        } catch (SQLException e) { throw new ServletException(e); }
    }
}