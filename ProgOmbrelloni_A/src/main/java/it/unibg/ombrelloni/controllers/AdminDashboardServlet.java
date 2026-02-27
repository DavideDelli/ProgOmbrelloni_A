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
import java.sql.ResultSet;
import java.sql.Statement;

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
        // Se non sei loggato come admin, ti rimando al login
        if (session == null || session.getAttribute("admin_logged_in") == null) {
            response.sendRedirect(request.getContextPath() + "/auth/admin_login");
            return;
        }

        int prenotazioniOggi = 0;
        int totaleOmbrelloni = 0;
        int totaleClienti = 0;
        double incassoStagione = 0.0;

        try (Connection conn = DatabaseManager.getInstance().getConnection();
             Statement st = conn.createStatement()) {

            // 1. Prenotazioni di oggi (ombrelloni occupati nella data odierna)
            String sqlOggi = "SELECT COUNT(DISTINCT idOmbrellone) FROM giornodisponibilita WHERE data = CURRENT_DATE AND numProgrContratto IS NOT NULL";
            try (ResultSet rs = st.executeQuery(sqlOggi)) {
                if (rs.next()) prenotazioniOggi = rs.getInt(1);
            }

            // 2. Totale ombrelloni a sistema
            try (ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM ombrellone")) {
                if (rs.next()) totaleOmbrelloni = rs.getInt(1);
            }

            // 3. Totale clienti registrati
            try (ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM cliente")) {
                if (rs.next()) totaleClienti = rs.getInt(1);
            }

            // 4. Incasso totale della stagione
            try (ResultSet rs = st.executeQuery("SELECT SUM(importo) FROM contratto")) {
                if (rs.next()) incassoStagione = rs.getDouble(1);
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        WebContext ctx = new WebContext(request, response, getServletContext(), request.getLocale());

        // Passiamo i dati calcolati al template Thymeleaf
        ctx.setVariable("prenotazioniOggi", prenotazioniOggi);
        ctx.setVariable("totaleOmbrelloni", totaleOmbrelloni);
        ctx.setVariable("totaleClienti", totaleClienti);

        // Formattiamo l'incasso come stringa per mostrare sempre 2 decimali (es. 150.50 invece di 150.5)
        ctx.setVariable("incassoStagione", String.format("%.2f", incassoStagione));

        templateEngine.process("admin/dashboard", ctx, response.getWriter());
    }
}