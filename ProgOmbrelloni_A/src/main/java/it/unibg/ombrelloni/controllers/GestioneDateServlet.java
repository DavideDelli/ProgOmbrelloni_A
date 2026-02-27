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
import java.sql.*;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@WebServlet("/admin/gestione_date")
public class GestioneDateServlet extends HttpServlet {
    private TemplateEngine templateEngine;

    @Override
    public void init() throws ServletException {
        this.templateEngine = (TemplateEngine) getServletContext().getAttribute(ThymeleafListener.TEMPLATE_ENGINE_ATTR);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("admin_logged_in") == null) {
            response.sendRedirect(request.getContextPath() + "/auth/admin_login");
            return;
        }

        WebContext ctx = new WebContext(request, response, getServletContext(), request.getLocale());
        ctx.setVariable("successo", request.getParameter("successo"));
        templateEngine.process("admin/gestione_date", ctx, response.getWriter());
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        LocalDate inizio = LocalDate.parse(request.getParameter("data_inizio"));
        LocalDate fine = LocalDate.parse(request.getParameter("data_fine"));

        try (Connection conn = DatabaseManager.getInstance().getConnection()) {
            // 1. Prendiamo tutti gli ID degli ombrelloni esistenti
            List<Integer> ids = new ArrayList<>();
            try (Statement st = conn.createStatement(); ResultSet rs = st.executeQuery("SELECT id FROM ombrellone")) {
                while (rs.next()) ids.add(rs.getInt("id"));
            }

            // 2. Per ogni giorno e ogni ombrellone, inseriamo la disponibilità
            String sql = "INSERT IGNORE INTO giornodisponibilita (data, idOmbrellone) VALUES (?, ?)";
            try (PreparedStatement pst = conn.prepareStatement(sql)) {
                for (LocalDate d = inizio; !d.isAfter(fine); d = d.plusDays(1)) {
                    for (Integer id : ids) {
                        pst.setDate(1, Date.valueOf(d));
                        pst.setInt(2, id);
                        pst.addBatch();
                    }
                }
                pst.executeBatch();
            }
            response.sendRedirect(request.getContextPath() + "/admin/gestione_date?successo=1");
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }
}