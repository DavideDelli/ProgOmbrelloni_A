package it.unibg.ombrelloni.config;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public class DatabaseManager {
    
    // Configurazione identica a db_connection.php
    private static final String URL = "jdbc:mysql://localhost:3306/my_ombrelloni?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true";
    private static final String USER = "root";
    private static final String PASSWORD = "";
    
    // Utilizziamo il pattern Singleton per gestire la connessione
    private static DatabaseManager instance;
    
    private DatabaseManager() {
        try {
            // Carica esplicitamente il driver JDBC (necessario per alcune versioni di Tomcat)
            Class.forName("com.mysql.cj.jdbc.Driver");
        } catch (ClassNotFoundException e) {
            throw new RuntimeException("Driver MySQL non trovato", e);
        }
    }
    
    public static synchronized DatabaseManager getInstance() {
        if (instance == null) {
            instance = new DatabaseManager();
        }
        return instance;
    }
    
    public Connection getConnection() throws SQLException {
        return DriverManager.getConnection(URL, USER, PASSWORD);
    }
}
