package it.unibg.ombrelloni.controllers;

import it.unibg.ombrelloni.dao.ClienteDAO;
import it.unibg.ombrelloni.models.Cliente;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import java.io.IOException;

@WebServlet("/auth/processa_accesso")
public class LoginServlet extends HttpServlet {

    private ClienteDAO clienteDAO;

    @Override
    public void init() throws ServletException {
        this.clienteDAO = new ClienteDAO();
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String codiceCliente = request.getParameter("codice_cliente");

        if (codiceCliente == null || codiceCliente.trim().isEmpty()) {
            response.sendRedirect(request.getContextPath() + "/accesso");
            return;
        }

        codiceCliente = codiceCliente.trim();
        Cliente cliente = clienteDAO.getClienteByCodice(codiceCliente);

        if (cliente != null) {
            HttpSession session = request.getSession(true);
            session.setAttribute("codice_cliente", cliente.getCodice());
            session.setAttribute("nome_cliente", cliente.getNome());
            session.setAttribute("cognome_cliente", cliente.getCognome());

            // FIX: Salviamo la data di nascita nella sessione (convertita in stringa YYYY-MM-DD per l'input date)
            if (cliente.getDataNascita() != null) {
                session.setAttribute("dataNascita_cliente", cliente.getDataNascita().toString());
            }

            // Se il login ha successo, andiamo alla mappa!
            response.sendRedirect(request.getContextPath() + "/mappa");
        } else {
            response.sendRedirect(request.getContextPath() + "/accesso?errore=1");
        }
    }
}