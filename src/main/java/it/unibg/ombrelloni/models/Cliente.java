package it.unibg.ombrelloni.models;

import java.time.LocalDate;

public class Cliente {
    private String codice;
    private String nome;
    private String cognome;
    private LocalDate dataNascita;
    private String indirizzo;

    // Costruttore vuoto (necessario per i JavaBean)
    public Cliente() {}

    public Cliente(String codice, String nome, String cognome, LocalDate dataNascita, String indirizzo) {
        this.codice = codice;
        this.nome = nome;
        this.cognome = cognome;
        this.dataNascita = dataNascita;
        this.indirizzo = indirizzo;
    }

    // Getter e Setter
    public String getCodice() { return codice; }
    public void setCodice(String codice) { this.codice = codice; }
    public String getNome() { return nome; }
    public void setNome(String nome) { this.nome = nome; }
    public String getCognome() { return cognome; }
    public void setCognome(String cognome) { this.cognome = cognome; }
    public LocalDate getDataNascita() { return dataNascita; }
    public void setDataNascita(LocalDate dataNascita) { this.dataNascita = dataNascita; }
    public String getIndirizzo() { return indirizzo; }
    public void setIndirizzo(String indirizzo) { this.indirizzo = indirizzo; }
}