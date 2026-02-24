
package it.unibg.ombrelloni.dao;

import it.unibg.ombrelloni.config.DatabaseManager;
import it.unibg.ombrelloni.models.Cliente;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;

public class ClienteDAO {

    public Cliente getClienteByCodice(String codiceCliente) {
        Cliente cliente = null;
        String sql = "SELECT * FROM cliente WHERE codice = ?";

        // Il try-with-resources chiude in automatico la connessione a fine blocco
        try (Connection conn = DatabaseManager.getInstance().getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, codiceCliente);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    cliente = new Cliente();
                    cliente.setCodice(rs.getString("codice"));
                    cliente.setNome(rs.getString("nome"));
                    cliente.setCognome(rs.getString("cognome"));
                    // Convertiamo la data SQL in LocalDate
                    java.sql.Date sqlDate = rs.getDate("dataNascita");
                    if (sqlDate != null) {
                        cliente.setDataNascita(sqlDate.toLocalDate());
                    }
                    cliente.setIndirizzo(rs.getString("indirizzo"));
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
            // In un progetto reale qui useremmo un logger
        }

        return cliente; // Ritorna null se non trova nessuno
    }

    public boolean salvaCliente(Cliente cliente) {
        String sql = "INSERT INTO cliente (codice, nome, cognome, dataNascita, indirizzo) VALUES (?, ?, ?, ?, ?)";
        try (Connection conn = DatabaseManager.getInstance().getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, cliente.getCodice());
            stmt.setString(2, cliente.getNome());
            stmt.setString(3, cliente.getCognome());
            // Convertiamo LocalDate in java.sql.Date per il database
            stmt.setDate(4, java.sql.Date.valueOf(cliente.getDataNascita()));
            stmt.setString(5, cliente.getIndirizzo());

            return stmt.executeUpdate() > 0;

        } catch (SQLException e) {
            e.printStackTrace();
            return false;
        }
    }
}