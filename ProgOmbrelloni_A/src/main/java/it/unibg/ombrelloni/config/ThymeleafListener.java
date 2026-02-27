package it.unibg.ombrelloni.config;

import org.thymeleaf.TemplateEngine;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.ServletContextTemplateResolver;

import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;
import javax.servlet.annotation.WebListener;

@WebListener
public class ThymeleafListener implements ServletContextListener {

    public static final String TEMPLATE_ENGINE_ATTR = "it.unibg.ombrelloni.TemplateEngineInstance";

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        ServletContext servletContext = sce.getServletContext();

        // Configura il risolutore dei template
        ServletContextTemplateResolver templateResolver = new ServletContextTemplateResolver(servletContext);
        templateResolver.setTemplateMode(TemplateMode.HTML);
        templateResolver.setPrefix("/WEB-INF/templates/"); // Cartella base
        templateResolver.setSuffix(".html");               // Estensione file
        templateResolver.setCharacterEncoding("UTF-8");
        templateResolver.setCacheable(false);              // Utile in fase di sviluppo

        // Crea il motore e associalo al contesto
        TemplateEngine templateEngine = new TemplateEngine();
        templateEngine.setTemplateResolver(templateResolver);

        servletContext.setAttribute(TEMPLATE_ENGINE_ATTR, templateEngine);
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        // Nessuna azione particolare alla chiusura
    }
}