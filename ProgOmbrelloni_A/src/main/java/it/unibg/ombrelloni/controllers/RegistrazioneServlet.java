package it.unibg.ombrelloni.controllers;

import it.unibg.ombrelloni.dao.ClienteDAO;
import it.unibg.ombrelloni.models.Cliente;
import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.WebContext;
import it.unibg.ombrelloni.config.ThymeleafListener;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.LocalDate;
import java.time.Period;
import java.util.ArrayList;
import java.util.List;

@WebServlet("/auth/salva_registrazione")
public class RegistrazioneServlet extends HttpServlet {

    private ClienteDAO clienteDAO;
    private TemplateEngine templateEngine;

    @Override
    public void init() throws ServletException {
        this.clienteDAO = new ClienteDAO();
        this.templateEngine = (TemplateEngine) getServletContext().getAttribute(ThymeleafListener.TEMPLATE_ENGINE_ATTR);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        response.setContentType("text/html;charset=UTF-8");
        request.setCharacterEncoding("UTF-8"); // Importante per gli accenti!

        WebContext ctx = new WebContext(request, response, getServletContext(), request.getLocale());
        List<String> errori = new ArrayList<>();

        String nome = request.getParameter("nome");
        String cognome = request.getParameter("cognome");
        String dataNascitaStr = request.getParameter("dataNascita");
        String indirizzo = request.getParameter("indirizzo");

        nome = (nome != null) ? nome.trim() : "";
        cognome = (cognome != null) ? cognome.trim() : "";
        indirizzo = (indirizzo != null && !indirizzo.trim().isEmpty()) ? indirizzo.trim() : null;

        // Validazioni fedeli all'originale PHP
        if (nome.isEmpty()) errori.add("Il campo Nome è obbligatorio.");
        if (cognome.isEmpty()) errori.add("Il campo Cognome è obbligatorio.");
        if (dataNascitaStr == null || dataNascitaStr.isEmpty()) errori.add("Il campo Data di Nascita è obbligatorio.");

        if (!nome.isEmpty() && !nome.matches("^[a-zA-Z' ]+$")) {
            errori.add("Il Nome può contenere solo lettere, spazi e apostrofi.");
        }
        if (!cognome.isEmpty() && !cognome.matches("^[a-zA-Z' ]+$")) {
            errori.add("Il Cognome può contenere solo lettere, spazi e apostrofi.");
        }

        LocalDate dataNascita = null;
        if (dataNascitaStr != null && !dataNascitaStr.isEmpty()) {
            try {
                dataNascita = LocalDate.parse(dataNascitaStr);
                LocalDate oggi = LocalDate.now();

                if (dataNascita.isAfter(oggi)) {
                    errori.add("La data di nascita non può essere nel futuro.");
                } else {
                    int eta = Period.between(dataNascita, oggi).getYears();
                    if (eta < 18) errori.add("Devi avere almeno 18 anni per registrarti.");
                    if (eta > 120) errori.add("La data di nascita inserita non è valida.");
                }
            } catch (Exception e) {
                errori.add("Formato data di nascita non valido.");
            }
        }

        // Se non ci sono errori, generiamo il codice e salviamo
        if (errori.isEmpty()) {
            // Generazione codice: CL + 1° lett nome + 1° lett cognome + timestamp
            String codiceGenerato = "CL" +
                    nome.substring(0, 1).toUpperCase() +
                    cognome.substring(0, 1).toUpperCase() +
                    System.currentTimeMillis();

            Cliente nuovoCliente = new Cliente(codiceGenerato, nome, cognome, dataNascita, indirizzo);

            if (clienteDAO.salvaCliente(nuovoCliente)) {
                ctx.setVariable("messaggio", "Registrazione completata con successo!");
                ctx.setVariable("codiceClienteGenerato", codiceGenerato);
            } else {
                errori.add("Si è verificato un errore tecnico durante la registrazione nel database.");
            }
        }

        // Passiamo gli errori al template
        ctx.setVariable("errori", errori);

        // Renderizziamo la pagina di esito
        templateEngine.process("auth/esito_registrazione", ctx, response.getWriter());
    }
}