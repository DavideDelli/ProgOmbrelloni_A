# 🏖️ Lido Codici Sballati

**Progetto Universitario per il corso di Programmazione Web** *Università degli Studi di Bergamo*

Un'applicazione web gestionale completa per uno stabilimento balneare. Il sistema permette ai clienti di registrarsi, visualizzare la mappa interattiva della spiaggia e prenotare gli ombrelloni (con diversi pacchetti tariffari). Offre inoltre un'area riservata agli amministratori per la gestione della stagione, l'aggiornamento dei prezzi e il monitoraggio degli incassi.

---

## 🛠️ Stack Tecnologico
L'applicativo è stato sviluppato seguendo il pattern architetturale **MVC (Model-View-Controller)**, garantendo una netta separazione tra logica di business, accesso ai dati e interfaccia utente.

* **Backend:** Java 21
* **Web Server:** Apache Tomcat 7 (tramite plugin Maven)
* **Templating Engine:** Thymeleaf 3
* **Database:** MySQL / MariaDB (con pattern DAO e Singleton)
* **Build Tool:** Apache Maven 3.9

---

## 🚀 Avvio Rapido "Zero-Config"

Il progetto è dotato di un sistema di bootstrap avanzato che installa autonomamente le dipendenze mancanti (Java, Maven, MySQL), inizializza il database, inietta le credenziali nel codice e avvia il server locale. **Non è richiesta alcuna configurazione manuale.**

### 🪟 Utenti Windows
1. Estrai o clona la repository sul tuo PC.
2. Fai doppio clic sul file `avvia.bat`.
3. *(Se richiesto dal Controllo Account Utente, concedi i privilegi di Amministratore).*
4. Attendi che il terminale completi le operazioni e mostri il messaggio di avvio di Tomcat.

### 🐧/🍏 Utenti Linux e macOS
1. Apri il terminale nella cartella del progetto.
2. Fornisci i permessi di esecuzione allo script:
   ```bash
   chmod +x avvia.sh
   ```
3. Lancia l'avvio automatico:
    ```bash
    ./avvia.sh
    ```
(Verrà richiesta la password di root per l'installazione dei pacchetti nativi e l'avvio del demone del database).

🌐 Utilizzo e Credenziali di Test
Una volta completato l'avvio, l'applicazione sarà disponibile all'indirizzo:

👉 http://localhost:8080/

Per testare le funzionalità, il database viene pre-caricato con i seguenti account:

Area Cliente: * Codice Accesso: CLIENTE0001 (Mario Rossi)

Area Amministratore (Dashboard): * URL: http://localhost:8080/auth/admin_login

Password: admin123

📖 Documentazione
Tutti i dettagli sulle scelte implementative, la progettazione del database, la gestione delle transazioni (ACID) e l'eventuale procedura di installazione manuale (Avanzata) sono consultabili nei file PDF allegati alla repository:

📄 manuale_utente.pdf

📄 scelte_progetto.pdf

👨‍💻 Sviluppato da:
Francesca Corrente (Matr. 1087460)

Davide Dell'Anno (Matr. 1085788)
