# Dokument wymagań produktu (PRD) - Numbers Evolution

## 1. Przegląd produktu

### 1.1 Nazwa produktu
Numbers Evolution

### 1.2 Cel projektu
Numbers Evolution to edukacyjna aplikacja webowa umożliwiająca testowanie i analizę różnych strategii typowania liczb w grze Eurojackpot. Projekt realizowany jest jako zaliczeniowy w ramach kursu 10xdevs i ma na celu demonstrację możliwości Phoenix LiveView, integracji AI oraz programowania współbieżnego w Elixir.

### 1.3 Grupa docelowa

Persona 1: Analityk Tomek
- Entuzjasta statystyki i analizy danych
- Lubi odkrywać wzorce w losowaniach
- Chce eksperymentować z różnymi parametrami strategii
- Preferuje kontrolę nad szczegółami

Persona 2: Gracz Marek
- Regularny gracz Eurojackpot
- Chce testować strategie bez wydawania pieniędzy
- Preferuje proste rozwiązania AI zamiast manualnej konfiguracji
- Szuka propozycji liczb na następne losowanie

### 1.4 Technologia

Stack technologiczny:
- Backend: Elixir/Phoenix Framework
- Frontend: Phoenix LiveView (real-time SPA)
- Baza danych: PostgreSQL
- AI Provider: OpenAI GPT-4 Turbo lub Claude 3.5 Sonnet
- Deployment: Fly.io (post-MVP)
- Autoryzacja: Phoenix phx.gen.auth

### 1.5 Model biznesowy
Aplikacja jest całkowicie darmowa bez limitów dla użytkowników. Brak planów monetyzacji.

### 1.6 Timeline
MVP1 planowany na 6 tygodni z pomocą AI w kodowaniu:
- Tydzień 1-2: Setup projektu, model danych, podstawowy layout
- Tydzień 3: Moduł strategii + CRUD
- Tydzień 4: Integracja AI generowania strategii
- Tydzień 5: Silnik symulacji
- Tydzień 6: LiveView tracking, ranking, generator propozycji, autoryzacja

## 2. Problem użytkownika

### 2.1 Główny problem
Użytkownicy chcą w ciekawy i edukacyjny sposób testować różne strategie typowania liczb w Eurojackpot, obserwować statystyki trafień oraz eksperymentować z mieszaniem strategii.

### 2.2 Obecne braki na rynku
Obecnie nie ma narzędzia, które umożliwiałoby:
- Generowanie propozycji liczb zgodnie z wybranymi strategiami (losowa, parzyste/nieparzyste, low/high, gorące/zimne liczby, zrównoważony rozkład), w tym automatycznie przez AI
- Symulowanie skuteczności strategii na danych historycznych i zliczanie liczby prób do trafienia głównej wygranej (5+2)
- Uruchamianie równoległych multisymulacji na wielu historycznych losowaniach jednocześnie
- Śledzenie postępu i wyników w czasie rzeczywistym z limitami czasowymi/prób
- Porównywanie i wybieranie najlepszych strategii oraz mixów strategii
- Generowanie propozycji liczb na najbliższe losowanie na podstawie najskuteczniejszych strategii

### 2.3 Wartość dla użytkownika
- Edukacyjne zrozumienie mechanizmów losowych i strategii
- Testowanie hipotez bez wydawania pieniędzy na kupony
- Oszczędność czasu dzięki automatyzacji AI
- Obiektywna analiza skuteczności różnych podejść
- Możliwość iteracyjnego doskonalenia strategii

## 3. Wymagania funkcjonalne

### 3.1 Autoryzacja użytkowników (F7)

F7.1 Rejestracja użytkownika
- Rejestracja przez email i hasło
- Bez walidacji siły hasła w MVP1
- Bez potwierdzenia email w MVP1

F7.2 Logowanie i wylogowanie
- Standard Phoenix auth
- Sesja użytkownika
- Bezpieczne przechowywanie haseł (bcrypt)

F7.3 Zmiana hasła
- Możliwość zmiany hasła przez zalogowanego użytkownika

F7.4 Izolacja danych
- Każdy użytkownik widzi tylko swoje dane (strategie, symulacje, wyniki)
- Scope w queries po user_id

### 3.2 Zarządzanie strategiami (F1)

F1.1 CRUD strategii
- Tworzenie nowej strategii
- Przeglądanie listy strategii
- Edycja istniejącej strategii
- Usuwanie strategii

F1.2 Tworzenie strategii manualnie
- Formularz z parametrami:
  - Ratio parzyste/nieparzyste (np. 2:3)
  - Ratio low/high - 1-25 vs 26-50 (np. 2:3)
  - Lista preferowanych gorących liczb (analiza danych historycznych)
  - Lista preferowanych zimnych liczb
  - Wagi dla różnych kryteriów (sumujące się do 1.0)
- Walidacja parametrów przy zapisie
- Zapisanie z typem "manual"

F1.3 Generowanie strategii przez AI
- Wprowadzanie promptu tekstowego w języku naturalnym
- System analizuje ostatnie 32 losowania
- AI uwzględnia wskazówki strategiczne z historycznych danych
- AI generuje strategię w formacie JSON zawierającym:
  - strategy_name
  - description
  - rules (struktura z wagami)
  - reasoning
  - game_type
- Walidacja odpowiedzi JSON
- Zapisanie z typem "ai_generated" oraz oryginalnym promptem
- Obsługa błędów: czerwony komunikat z detalami + przycisk "Spróbuj ponownie"

F1.4 Przechowywanie strategii
- Struktura w bazie danych:
  - id (UUID)
  - user_id (FK)
  - name (string)
  - type (enum: manual, ai_generated)
  - ai_prompt (text, nullable)
  - rules (JSONB)
  - performance_score (float, nullable)
  - inserted_at, updated_at

F1.5 Mieszanie strategii
- Zaznaczanie 2-3 strategii jako składowych miksu
- AI generuje nową strategię łączącą reguły
- Rozwiązywanie konfliktów: priorytet dla strategii z wyższym performance_score
- Mix zapisany jako nowa osobna strategia (bez dodatkowej tabeli strategy_mixes)

### 3.3 Dane historyczne Eurojackpot (F6)

F6.1 Seed losowań
- Import i przechowywanie minimum 100-200 ostatnich losowań
- Dane jako fixtures/seeding

F6.2 Struktura uniwersalna
- Tabela draws z polami:
  - id (UUID)
  - draw_date (date, unique)
  - game_type (string) - "eurojackpot"
  - numbers (JSONB) - {"main_numbers": [...], "euro_numbers": [...]}
  - inserted_at, updated_at

F6.3 Aktualizacja danych
- Ręczne dodawanie nowych wyników przez seeding/migrations (1x w tygodniu)
- Brak admin panelu w MVP1

### 3.4 Silnik symulacji (F2)

F2.1 Uruchamianie pojedynczej symulacji
- Wybór strategii z listy użytkownika
- Wybór historycznego losowania jako targetu
- Opcjonalne dostosowanie limitów

F2.2 Proces symulacji
- Generowanie zestawów liczb zgodnie z regułami strategii w pętli
- Porównywanie z target_draw po każdej generacji
- Sprawdzanie czy trafiono 5 głównych liczb + 2 euro liczby
- Ignorowanie innych stopni wygranej (tylko 5+2 w MVP1)

F2.3 Limity bezpieczeństwa
- Timeout: default 300 sekund
- Max liczba prób: default 1 milion
- Symulacja kończy się gdy: trafiono 5+2 LUB osiągnięto limit prób LUB timeout

F2.4 Wykonanie w tle
- Task.async dla każdej symulacji
- Symulacja kontynuuje działanie nawet po zamknięciu przeglądarki
- Proper timeout handling

F2.5 Zapis wyniku
- Zapisywanie do tabeli simulations:
  - id (UUID)
  - user_id (FK)
  - strategy_id (FK)
  - target_draw_id (FK)
  - attempts_count (integer)
  - duration_seconds (float)
  - status (enum: success, timeout, error)
  - result (JSONB) - matched numbers
  - inserted_at

### 3.5 Live tracking w LiveView (F3)

F3.1 Real-time aktualizacja
- Licznik prób aktualizowany co 2 sekundy
- Komunikacja przez LiveView messaging

F3.2 Wyświetlane informacje
- Liczba prób (counter)
- Czas trwania symulacji
- Status (running/success/timeout)

F3.3 Ograniczenia MVP1
- Brak przycisku Stop
- Brak ETA (estimated time of arrival)
- Brak wykresów postępu

### 3.6 Ranking i analiza wyników (F4)

F4.1 Obliczanie performance_score
- Mediana liczby prób dla każdej strategii (główna metryka)
- Kalkulacja po każdej nowej symulacji

F4.2 Ranking strategii
- Lista posortowana według mediany prób (rosnąco)
- Najniższa mediana = najlepsza strategia

F4.3 Wyświetlane dane
- Nazwa strategii
- Typ (manual/ai_generated)
- Mediana liczby prób
- Liczba przeprowadzonych symulacji
- Performance_score

F4.4 Historia symulacji
- Lista wszystkich symulacji użytkownika
- Sortowanie: najnowsze na górze
- Filtrowanie po strategii
- Szczegóły: strategia, target draw, liczba prób, czas, status

F4.5 Ranking mixów strategii
- Po multisymulacjach wyświetlanie które kombinacje najlepsze
- Porównywanie skuteczności mixów z pojedynczymi strategiami

### 3.7 Multisymulacje (MVP2 - Enhanced)

F-MS.1 Równoległe uruchamianie
- 3-10 symulacji jednocześnie
- Każda na innym historycznym losowaniu
- Task.async dla równoległości

F-MS.2 Limity multisymulacji
- Max 10 równoległych symulacji w MVP2
- Każda z własnymi limitami timeout/max prób

F-MS.3 Monitoring postępu
- Live tracking wszystkich równoległych symulacji
- Agregowane statystyki

### 3.8 Generator propozycji na losowanie (F5)

F5.1 Identyfikacja top strategii
- System znajduje top 3 strategie użytkownika wg mediany prób
- Jeśli brak symulacji: oferuje wygenerowanie nowej strategii przez AI

F5.2 Konfiguracja generowania
- Wybór liczby kuponów (1-10)
- Wybór strategii do użycia (z top 3)

F5.3 Generowanie kuponów
- N unikalnych zestawów 5 głównych liczb (1-50) + 2 euro liczby (1-12)
- Zgodnie z regułami wybranej strategii
- Walidacja: żadne dwa kupony nie są identyczne

F5.4 UI generatora
- Wizualizacja jako "kule" z numerami
- Przycisk "Wylosuj inne" (regeneracja)
- Brak exportu do pliku w MVP1
- Brak przycisku "Kopiuj wszystkie" w MVP1

### 3.9 Dashboard LiveView (F8)

F8.1 Architektura Single Page Application
- Jedna strona główna (/) obsługująca całość w LiveView
- Sekcje pojawiające się/ukrywane na klik
- Nie używać /dashboard (zajęty w Phoenix)
- Brak przeładowania strony

F8.2 Landing page (przed logowaniem)
- Opis aplikacji
- Call-to-action: Login/Register

F8.3 Dashboard (po logowaniu)
- Statystyki użytkownika:
  - Liczba strategii
  - Liczba symulacji
  - Najlepsza strategia (najniższa mediana)
- Quick actions:
  - Utwórz nową strategię
  - Uruchom symulację
  - Generuj propozycje

F8.4 Sekcja zarządzania strategiami
- Lista wszystkich strategii użytkownika
- CRUD operations (Create, Read, Update, Delete)
- Formularz nowej strategii z tabami:
  - Tab "Manualna" - formularz z parametrami
  - Tab "AI" - pole tekstowe na prompt
- Widok szczegółów strategii:
  - Nazwa, typ, rules
  - Historia symulacji dla tej strategii
  - Performance score

F8.5 Sekcja symulacji
- Formularz uruchomienia:
  - Wybór strategii
  - Wybór target draw
  - Opcjonalne limity
- Live tracking (real-time)
- Historia wyników symulacji

F8.6 Sekcja rankingu
- Lista strategii posortowana wg mediany prób
- Możliwość kliknięcia dla szczegółów

F8.7 Sekcja generatora propozycji
- Top 3 strategie
- Konfiguracja (ile kuponów, która strategia)
- Wyświetlenie wygenerowanych kuponów
- Opcja regeneracji

## 4. Granice produktu

### 4.1 Co NIE wchodzi w zakres MVP1

4.1.1 Dodatkowe gry losowe
- Multi Multi, Lotto, Keno - nie w MVP
- Tylko Eurojackpot w pierwszej wersji
- Architektura przygotowana na rozbudowę (game_type w strukturze)

4.1.2 Zaawansowane algorytmy ewolucyjne
- Brak algorytmów genetycznych w MVP
- Brak automatycznej ewolucji strategii w wielu pokoleniach
- MVP: tylko podstawowe mieszanie kilku strategii przez AI

4.1.3 Funkcje kontroli symulacji
- Brak przycisku "Stop" do przerwania symulacji w MVP1
- Symulacja musi się zakończyć naturalnie (sukces/timeout)

4.1.4 Rozszerzone multisymulacje
- Max 10 równoległych symulacji w MVP2
- Brak multisymulacji w MVP1

4.1.5 Śledzenie wszystkich stopni wygranej
- MVP śledzi TYLKO główną wygraną (5+2)
- Nie śledzone w MVP:
  - Stopień II (5+1)
  - Stopień III (5+0)
  - Stopień IV (4+2)
  - Stopień V (4+1)
  - Stopień VI (3+2)
  - Stopień VII (4+0)
- Brak zliczania ile razy każdy stopień został trafiony
- Tracking wszystkich stopni to rozbudowa post-MVP

4.1.6 Zaawansowana analiza i wizualizacja
- Brak wykresów trendu
- Brak heatmap
- Brak analizy korelacji
- Podstawowe tabelaryczne wyświetlanie wyników

4.1.7 Automatyzacja danych
- Brak automatycznego importu wyników z API Totalizatora Sportowego
- Aktualizacja danych: ręczna przez seeding

4.1.8 Integracje zewnętrzne
- Brak integracji z systemami hazardowymi
- Brak płatności (aplikacja darmowa)
- Brak API publicznego

4.1.9 Funkcje społecznościowe
- Brak współdzielenia strategii między użytkownikami
- Brak publicznych rankingów
- Każdy user widzi tylko swoje dane

4.1.10 Wersje mobilne
- Brak dedykowanych aplikacji iOS/Android
- Responsive design dla przeglądarek mobilnych (LiveView)

4.1.11 Eksport i powiadomienia
- Brak exportu raportów do PDF/Excel
- Brak powiadomień email/push o ukończonych symulacjach

4.1.12 Zaawansowane AI
- Brak Machine Learning do predykcji
- MVP: tylko podstawowe reguły + proste AI sugestie
- AI używane do generowania strategii, nie do predykcji wyników

4.1.13 Optymalizacje API
- Brak cache'owania odpowiedzi AI dla podobnych promptów
- Brak rate limiting dla generowania strategii
- Proste wywołania API bez dodatkowych warstw

4.1.14 Admin panel
- Brak interfejsu administracyjnego w MVP1
- Brak zarządzania użytkownikami przez UI
- Dane seedowane przez migrations

4.1.15 Zaawansowana autoryzacja
- Brak OAuth (Google, Facebook)
- Brak potwierdzenia email przy rejestracji
- Brak funkcji resetowania hasła w MVP1
- Brak walidacji siły hasła

### 4.2 Disclaimer prawny
Aplikacja służy wyłącznie celom edukacyjnym i symulacyjnym. Nie gwarantuje wygranej i nie jest oficjalnie powiązana z operatorami loterii.

## 5. Historyjki użytkowników

### US-001: Rejestracja nowego użytkownika

Tytuł: Rejestracja konta w systemie

Opis:
Jako nowy użytkownik
Chcę założyć konto w systemie podając email i hasło
Aby móc korzystać z aplikacji i zapisywać swoje strategie

Kryteria akceptacji:
- Użytkownik widzi formularz rejestracji z polami: email, hasło, powtórz hasło
- Walidacja formatu email (standard Phoenix)
- Hasło musi mieć minimum 8 znaków (basic validation)
- Pola "hasło" i "powtórz hasło" muszą być identyczne
- Po udanej rejestracji użytkownik jest automatycznie zalogowany
- Po udanej rejestracji następuje redirect na dashboard
- System wyświetla komunikat błędu jeśli email już istnieje w bazie
- Hasło jest hashowane przed zapisem (bcrypt)

### US-002: Logowanie do systemu

Tytuł: Logowanie użytkownika

Opis:
Jako zarejestrowany użytkownik
Chcę zalogować się do systemu podając email i hasło
Aby uzyskać dostęp do swoich strategii i symulacji

Kryteria akceptacji:
- Użytkownik widzi formularz logowania z polami: email, hasło
- Po poprawnym logowaniu następuje redirect na dashboard
- Sesja użytkownika jest utrzymywana
- System wyświetla komunikat błędu przy niepoprawnych danych
- Po zalogowaniu użytkownik widzi tylko swoje dane (izolacja po user_id)

### US-003: Wylogowanie z systemu

Tytuł: Wylogowanie użytkownika

Opis:
Jako zalogowany użytkownik
Chcę móc się wylogować z systemu
Aby zabezpieczyć swoje konto

Kryteria akceptacji:
- Użytkownik widzi przycisk/link "Wyloguj" w nawigacji
- Po kliknięciu następuje wylogowanie i usunięcie sesji
- Po wylogowaniu redirect na landing page
- Próba dostępu do chronionych zasobów po wylogowaniu przekierowuje na login

### US-004: Zmiana hasła

Tytuł: Zmiana hasła przez zalogowanego użytkownika

Opis:
Jako zalogowany użytkownik
Chcę móc zmienić swoje hasło
Aby zwiększyć bezpieczeństwo mojego konta

Kryteria akceptacji:
- Użytkownik ma dostęp do formularza zmiany hasła w ustawieniach
- Formularz zawiera pola: obecne hasło, nowe hasło, powtórz nowe hasło
- Walidacja obecnego hasła
- Nowe hasło musi mieć minimum 8 znaków
- Pola "nowe hasło" i "powtórz nowe hasło" muszą być identyczne
- Po udanej zmianie system wyświetla komunikat sukcesu
- Nowe hasło jest hashowane przed zapisem

### US-005: Przeglądanie listy strategii

Tytuł: Wyświetlenie wszystkich strategii użytkownika

Opis:
Jako użytkownik systemu
Chcę zobaczyć listę wszystkich moich strategii
Aby móc nimi zarządzać i wybierać do symulacji

Kryteria akceptacji:
- Użytkownik widzi listę wszystkich swoich strategii
- Każda strategia wyświetla: nazwę, typ (manual/ai_generated), performance_score
- Lista jest posortowana według mediany prób (rosnąco) - najlepsze na górze
- Użytkownik widzi tylko swoje strategie (scope po user_id)
- Lista zawiera przyciski akcji: Edytuj, Usuń, Zobacz szczegóły
- Jeśli brak strategii, wyświetlany jest komunikat i przycisk "Utwórz pierwszą strategię"

### US-006: Tworzenie strategii manualnie

Tytuł: Utworzenie nowej strategii z parametrami ręcznymi

Opis:
Jako Analityk Tomek (persona 1)
Chcę móc stworzyć strategię typowania ręcznie ustawiając parametry
Aby przetestować własne intuicje dotyczące rozkładu liczb

Kryteria akceptacji:
- Użytkownik ma dostęp do formularza tworzenia strategii manualnej (Tab "Manualna")
- Formularz zawiera pola:
  - Nazwa strategii (text, wymagane)
  - Ratio parzyste/nieparzyste dla głównych liczb (np. 2:3)
  - Ratio low/high dla głównych liczb (1-25 vs 26-50, np. 2:3)
  - Lista preferowanych gorących liczb (multi-select lub text)
  - Lista preferowanych zimnych liczb (multi-select lub text)
  - Wagi dla kryteriów: hot, cold, random (sumujące się do 1.0)
  - Analogiczne ustawienia dla euro liczb (ratio parzyste/nieparzyste, preferowane liczby)
- Walidacja: wagi muszą sumować się do 1.0
- Walidacja: strategia musi być matematycznie poprawna
- Walidacja: strategia musi móc generować różne zestawy liczb
- Po zapisie strategia ma typ "manual"
- System wyświetla komunikat sukcesu i przekierowuje do listy strategii
- Błędy walidacji wyświetlane są w formularzu (LiveView changeset errors)

### US-007: Generowanie strategii przez AI - podstawowe

Tytuł: Wygenerowanie strategii przez AI z prostego promptu

Opis:
Jako Gracz Marek (persona 2)
Chcę opisać słowami jaki typ strategii mnie interesuje
Aby AI wygenerowało dla mnie parametry bez męczenia się z formularzem

Kryteria akceptacji:
- Użytkownik ma dostęp do formularza AI (Tab "AI")
- Formularz zawiera:
  - Pole tekstowe na prompt (textarea, wymagane)
  - Przykłady promptów (placeholder lub hint)
  - Przycisk "Generuj strategię AI"
- Po kliknięciu przycisku system:
  - Wyświetla loader/spinner
  - Pobiera ostatnie 32 losowania z bazy
  - Analizuje gorące/zimne liczby
  - Tworzy strukturalny prompt dla AI zawierający:
    - Dane historyczne (32 losowania)
    - Wskazówki strategiczne
    - Skuteczność poprzednich strategii użytkownika (jeśli istnieją)
    - Instrukcję użytkownika (prompt)
  - Wysyła request do AI API
- AI zwraca odpowiedź w formacie JSON z polami:
  - strategy_name
  - description
  - rules (struktura JSONB z wagami)
  - reasoning
  - game_type
- System waliduje JSON
- Strategia zapisuje się do bazy z typem "ai_generated" i oryginalnym promptem
- System wyświetla komunikat sukcesu i pokazuje wygenerowaną strategię
- Użytkownik widzi reasoning (uzasadnienie) od AI

### US-008: Obsługa błędów AI podczas generowania strategii

Tytuł: Informowanie użytkownika o błędzie AI

Opis:
Jako użytkownik próbujący wygenerować strategię przez AI
Chcę zobaczyć jasny komunikat jeśli AI nie może wygenerować strategii
Aby wiedzieć co się stało i móc spróbować ponownie

Kryteria akceptacji:
- Jeśli AI zwróci błąd (timeout, invalid JSON, API error), system:
  - Wyświetla czerwony komunikat o niepowodzeniu
  - Pokazuje szczegóły błędu dla użytkownika (np. "Timeout API", "Nieprawidłowy format odpowiedzi")
  - Wyświetla przycisk "Spróbuj ponownie"
- Kliknięcie "Spróbuj ponownie" ponownie uruchamia generowanie z tym samym promptem
- Nie ma automatycznego fallbacku do strategii losowej
- Użytkownik może edytować prompt i spróbować ponownie
- Błędy są logowane dla debugowania

### US-009: Edycja istniejącej strategii

Tytuł: Modyfikacja parametrów strategii

Opis:
Jako użytkownik systemu
Chcę móc edytować istniejącą strategię
Aby dostosować jej parametry na podstawie wyników symulacji

Kryteria akceptacji:
- Użytkownik może kliknąć "Edytuj" przy strategii na liście
- Formularz edycji jest przedwypełniony aktualnymi danymi strategii
- Dla strategii "manual": możliwość edycji wszystkich parametrów
- Dla strategii "ai_generated": możliwość edycji nazwy i description, rules pozostają niemodyfikowalne (lub można wygenerować nową strategię)
- Po zapisie zmiany są natychmiast widoczne
- Performance_score jest przeliczany po kolejnych symulacjach (nie resetuje się przy edycji)
- System wyświetla komunikat sukcesu

### US-010: Usuwanie strategii

Tytuł: Usunięcie strategii z systemu

Opis:
Jako użytkownik systemu
Chcę móc usunąć strategię której już nie potrzebuję
Aby utrzymać porządek w mojej liście

Kryteria akceptacji:
- Użytkownik może kliknąć "Usuń" przy strategii na liście
- System wyświetla dialog potwierdzenia: "Czy na pewno usunąć strategię [nazwa]?"
- Po potwierdzeniu strategia jest usuwana z bazy
- Symulacje powiązane ze strategią pozostają w bazie (FK ustawione na nullable lub cascade decision)
- System wyświetla komunikat sukcesu
- Lista strategii jest odświeżana

### US-011: Wyświetlanie szczegółów strategii

Tytuł: Przeglądanie pełnych informacji o strategii

Opis:
Jako użytkownik systemu
Chcę zobaczyć szczegóły wybranej strategii
Aby zrozumieć jej parametry i zobaczyć historię symulacji

Kryteria akceptacji:
- Użytkownik może kliknąć na strategię aby zobaczyć szczegóły
- Widok szczegółów zawiera:
  - Nazwę strategii
  - Typ (manual/ai_generated)
  - Opis (description)
  - Szczegółowe rules (JSON sformatowany czytelnie)
  - Performance_score i medianę prób
  - Reasoning (dla ai_generated)
  - Oryginalny prompt (dla ai_generated)
  - Listę wszystkich symulacji dla tej strategii:
    - Target draw (data losowania)
    - Liczba prób
    - Czas trwania
    - Status
  - Przyciski akcji: Edytuj, Usuń, Uruchom symulację

### US-012: Tworzenie miksu strategii

Tytuł: Połączenie 2-3 strategii w hybrydę

Opis:
Jako Analityk Tomek (persona 1)
Chcę połączyć dwie strategie (np. "tylko nieparzyste" + "tylko 20-40")
Aby stworzyć hybrydę respektującą oba ograniczenia

Kryteria akceptacji:
- Użytkownik może zaznaczyć 2-3 strategie z listy (checkboxy)
- Przycisk "Utwórz mix" staje się aktywny gdy zaznaczone 2-3 strategie
- Po kliknięciu system:
  - Analizuje rules wszystkich składowych strategii
  - Sprawdza konflikty (np. jedna wymaga parzyste, druga nieparzyste)
  - Jeśli konflikt: wyświetla komunikat o niemożności połączenia lub propozycję kompromisu
  - AI generuje nową strategię łączącą reguły:
    - Strategia z wyższym performance_score ma priorytet przy konfliktach
    - AI tworzy optymalizowaną kombinację rules
- Nowa strategia zapisana jako osobny byt (nie w dodatkowej tabeli strategy_mixes)
- Nazwa automatyczna: "[Strategia1] + [Strategia2] Mix" (możliwość edycji)
- Typ: "ai_generated"
- Mix może być używany jak zwykła strategia w symulacjach

### US-013: Uruchamianie pojedynczej symulacji

Tytuł: Test strategii na historycznym losowaniu

Opis:
Jako użytkownik systemu
Chcę uruchomić symulację dla mojej strategii na historycznym losowaniu
Aby zobaczyć ile prób byłoby potrzebnych do trafienia głównej wygranej

Kryteria akceptacji:
- Użytkownik ma dostęp do formularza uruchomienia symulacji
- Formularz zawiera:
  - Wybór strategii (dropdown z listą strategii użytkownika)
  - Wybór historycznego losowania (dropdown z datami)
  - Opcjonalne limity:
    - Max liczba prób (default: 1,000,000)
    - Timeout w sekundach (default: 300)
  - Przycisk "Uruchom symulację"
- Po kliknięciu:
  - Symulacja uruchamia się w tle (Task.async)
  - Użytkownik widzi live tracking (real-time)
  - LiveView aktualizuje licznik prób co 2 sekundy
  - Wyświetlany czas trwania
  - Wyświetlany status: "running"
- Symulacja kończy się gdy:
  - Trafiono 5+2 (status: "success")
  - Osiągnięto max liczba prób (status: "timeout")
  - Timeout w sekundach (status: "timeout")
  - Wystąpił błąd (status: "error")
- Wynik zapisuje się do tabeli simulations z:
  - attempts_count
  - duration_seconds
  - status
  - result (matched numbers JSON)
- Po zakończeniu system wyświetla komunikat z wynikiem

### US-014: Live tracking symulacji w czasie rzeczywistym

Tytuł: Obserwowanie postępu uruchomionej symulacji

Opis:
Jako użytkownik który uruchomił symulację
Chcę widzieć postęp w czasie rzeczywistym
Aby monitorować jak strategia radzi sobie z trafieniem wygranej

Kryteria akceptacji:
- Podczas działania symulacji użytkownik widzi:
  - Licznik prób (aktualizowany co 2 sekundy przez LiveView)
  - Czas trwania (format MM:SS)
  - Status: "running" z animacją (spinner)
- Aktualizacje następują automatycznie bez przeładowania strony (LiveView messaging)
- Użytkownik może zamknąć przeglądarkę - symulacja kontynuuje w tle
- Po powrocie użytkownik widzi aktualny stan (jeśli wciąż running) lub wynik (jeśli zakończona)
- Brak przycisku Stop w MVP1
- Brak ETA (estimated time of arrival) w MVP1
- Brak wykresów postępu w MVP1

### US-015: Przeglądanie historii symulacji

Tytuł: Wyświetlenie wszystkich przeprowadzonych symulacji

Opis:
Jako użytkownik systemu
Chcę zobaczyć historię wszystkich moich symulacji
Aby analizować wyniki i porównywać skuteczność strategii

Kryteria akceptacji:
- Użytkownik widzi listę wszystkich swoich symulacji
- Lista posortowana: najnowsze na górze
- Każda pozycja zawiera:
  - Nazwa strategii (link do szczegółów strategii)
  - Data i godzina uruchomienia
  - Target draw (data historycznego losowania)
  - Liczba prób (attempts_count)
  - Czas trwania (duration_seconds)
  - Status (success/timeout/error) z kolorowym wskaźnikiem
- Możliwość filtrowania po:
  - Strategii
  - Statusie
  - Dacie
- Możliwość kliknięcia symulacji dla pełnych szczegółów:
  - Result JSON (matched numbers)
  - Szczegóły strategii użytej
  - Szczegóły target draw

### US-016: Ranking strategii według skuteczności

Tytuł: Porównanie strategii wg mediany prób

Opis:
Jako użytkownik systemu
Chcę zobaczyć ranking moich strategii według skuteczności
Aby wiedzieć która działa najlepiej

Kryteria akceptacji:
- Użytkownik widzi sekcję "Ranking strategii"
- Lista wszystkich strategii użytkownika posortowana wg mediany liczby prób (rosnąco)
- Dla każdej strategii wyświetlane:
  - Pozycja w rankingu (#1, #2, #3...)
  - Nazwa strategii
  - Typ (manual/ai_generated)
  - Mediana liczby prób (główna metryka)
  - Liczba symulacji użyta do obliczenia
  - Performance_score
- Top 3 strategie wyróżnione wizualnie (np. złoty/srebrny/brązowy badge)
- Strategie bez symulacji na końcu listy z oznaczeniem "Brak danych"
- Możliwość kliknięcia strategii dla szczegółów
- Ranking aktualizuje się automatycznie po każdej nowej symulacji

### US-017: Ranking mixów strategii po multisymulacjach

Tytuł: Porównanie skuteczności kombinacji strategii

Opis:
Jako użytkownik systemu
Chcę zobaczyć ranking mixów strategii
Aby wiedzieć które kombinacje są najskuteczniejsze

Kryteria akceptacji:
- Użytkownik widzi sekcję "Ranking mixów"
- Lista mixów (strategii powstałych z połączenia) posortowana wg mediany
- Dla każdego miksu wyświetlane:
  - Nazwa miksu
  - Strategie składowe (linki)
  - Mediana liczby prób
  - Liczba symulacji
  - Porównanie z medianami strategii składowych (np. "20% lepiej niż składowe")
- Możliwość kliknięcia miksu dla szczegółów
- Ranking aktualizuje się po multisymulacjach

### US-018: Uruchamianie multisymulacji równoległych (MVP2)

Tytuł: Równoczesne testowanie strategii na wielu losowaniach

Opis:
Jako użytkownik systemu
Chcę uruchomić wiele symulacji równocześnie na różnych historycznych losowaniach
Aby szybciej uzyskać statystyki skuteczności strategii

Kryteria akceptacji:
- Użytkownik ma dostęp do formularza multisymulacji
- Formularz zawiera:
  - Wybór strategii
  - Wybór liczby równoległych symulacji (3-10)
  - System automatycznie wybiera N różnych historycznych losowań jako targety
  - Opcjonalne limity (max prób, timeout) - wspólne dla wszystkich
  - Przycisk "Uruchom multisymulację"
- Po uruchomieniu:
  - 3-10 Task.async uruchamianych równolegle
  - Live tracking wszystkich symulacji jednocześnie
  - Każda symulacja wyświetla: target draw, licznik prób, status
  - Agregowane statystyki: ile ukończonych, ile running
- Po zakończeniu wszystkich:
  - Wyświetlenie sumarycznych statystyk
  - Mediana prób obliczana z wszystkich wyników
  - Aktualizacja performance_score strategii
- Limit: max 10 równoległych symulacji

### US-019: Generowanie propozycji kuponów - wybór strategii

Tytuł: Wygenerowanie liczb na najbliższe losowanie

Opis:
Jako Gracz Marek (persona 2)
Chcę wygenerować propozycje liczb na następne losowanie
Aby użyć ich do faktycznego zakupu kuponu

Kryteria akceptacji:
- Użytkownik ma dostęp do sekcji "Generator propozycji"
- System wyświetla top 3 najskuteczniejsze strategie użytkownika (według mediany)
- Jeśli użytkownik nie ma żadnych symulacji:
  - System wyświetla komunikat "Najpierw uruchom symulacje aby znaleźć najlepsze strategie"
  - Oferuje link do wygenerowania nowej strategii przez AI
  - Oferuje link do uruchomienia symulacji
- Użytkownik może wybrać:
  - Którą strategię użyć (z top 3 lub dowolną inną)
  - Ile kuponów wygenerować (slider/input: 1-10)
- Przycisk "Generuj propozycje"

### US-020: Wyświetlanie wygenerowanych kuponów

Tytuł: Wizualizacja propozycji liczb

Opis:
Jako użytkownik który wygenerował propozycje
Chcę zobaczyć kupony w czytelnej formie
Aby móc je łatwo przepisać lub zapamiętać

Kryteria akceptacji:
- System generuje N unikalnych zestawów liczb zgodnie z regułami wybranej strategii
- Każdy zestaw zawiera:
  - 5 głównych liczb (1-50)
  - 2 euro liczby (1-12)
- Walidacja: żadne dwa kupony nie są identyczne
- Kupony wyświetlone jako wizualne "kule" z numerami:
  - Główne liczby w jednym rzędzie (5 kul)
  - Euro liczby w drugim rzędzie (2 kule)
  - Różne kolory dla głównych vs euro liczb
- Numeracja kuponów: Kupon 1, Kupon 2, etc.
- Każdy kupon w osobnej sekcji/karcie

### US-021: Regeneracja propozycji kuponów

Tytuł: Wygenerowanie innych zestawów liczb

Opis:
Jako użytkownik który wygenerował propozycje
Chcę móc wygenerować inne zestawy
Aby zobaczyć różne warianty zgodne ze strategią

Kryteria akceptacji:
- Przycisk "Wylosuj inne" widoczny pod kuponami
- Kliknięcie generuje nowe N kuponów z tą samą strategią
- Nowe kupony natychmiast zastępują poprzednie (bez przeładowania - LiveView)
- Walidacja: nowe kupony są różne od poprzednich i między sobą
- Brak limitu regeneracji w MVP1
- Brak zapisywania historii wygenerowanych kuponów w MVP1

### US-022: Przeglądanie dashboard po zalogowaniu

Tytuł: Widok główny z podsumowaniem i szybkimi akcjami

Opis:
Jako zalogowany użytkownik
Chcę zobaczyć dashboard z moimi statystykami
Aby szybko zorientować się w stanie mojego konta i podjąć akcję

Kryteria akceptacji:
- Po zalogowaniu użytkownik widzi dashboard
- Dashboard wyświetla:
  - Powitanie z imieniem/emailem użytkownika
  - Statystyki:
    - Liczba utworzonych strategii
    - Liczba przeprowadzonych symulacji
    - Najlepsza strategia (nazwa + mediana prób)
    - Ostatnia aktywność (data)
  - Quick actions (duże przyciski):
    - "Utwórz nową strategię"
    - "Uruchom symulację"
    - "Generuj propozycje na losowanie"
  - Ostatnie 5 symulacji (mini lista z linkami do szczegółów)
- Wszystko na jednej stronie bez przeładowania (LiveView SPA)
- Sekcje dynamicznie ładowane/ukrywane na klik

### US-023: Nawigacja między sekcjami aplikacji

Tytuł: Przełączanie się między funkcjonalnościami

Opis:
Jako użytkownik systemu
Chcę łatwo nawigować między różnymi sekcjami aplikacji
Aby efektywnie korzystać ze wszystkich funkcjonalności

Kryteria akceptacji:
- Nawigacja górna (menu) zawiera linki:
  - Dashboard
  - Strategie
  - Symulacje
  - Ranking
  - Generator
  - Wyloguj
- Kliknięcie linku nie przeładowuje strony (LiveView)
- Aktywna sekcja jest wizualnie wyróżniona
- Wszystko dzieje się na jednej stronie (/)
- Nie używamy URL /dashboard (zajęty w Phoenix)
- Responsywny design dla mobile (hamburger menu)

### US-024: Przeglądanie landing page przed zalogowaniem

Tytuł: Informacja o aplikacji dla niezalogowanych

Opis:
Jako nowy odwiedzający
Chcę zobaczyć co oferuje aplikacja
Aby zdecydować czy warto się zarejestrować

Kryteria akceptacji:
- Strona główna (/) dla niezalogowanych wyświetla:
  - Nazwę aplikacji: "Numbers Evolution"
  - Tagline: krótki opis (np. "Testuj strategie typowania Eurojackpot z pomocą AI")
  - Główne funkcjonalności (bullet points):
    - Tworzenie strategii manualnie lub przez AI
    - Symulacje na danych historycznych
    - Ranking skuteczności
    - Generator propozycji na losowanie
  - Disclaimer: "Aplikacja służy wyłącznie celom edukacyjnym"
  - Call-to-action: duże przyciski "Zarejestruj się" i "Zaloguj"
- Nowoczesny, przyjazny design
- Brak dostępu do funkcjonalności bez logowania

### US-025: Walidacja strategii przy zapisie

Tytuł: Sprawdzenie poprawności parametrów strategii

Opis:
Jako użytkownik tworzący strategię
Chcę otrzymać feedback o błędach zanim strategia zostanie zapisana
Aby upewnić się że strategia jest matematycznie poprawna

Kryteria akceptacji:
- Walidacja wykonywana przy zapisie strategii (nie przed symulacją)
- Sprawdzenia:
  - Nazwa strategii nie jest pusta
  - Wagi sumują się do 1.0 (tolerance ±0.001)
  - Ratio parzyste/nieparzyste sumuje się do 5 dla głównych liczb
  - Ratio low/high sumuje się do 5 dla głównych liczb
  - Preferowane liczby są w prawidłowym zakresie (1-50 dla głównych, 1-12 dla euro)
  - Strategia może generować różne zestawy (nie tylko jeden zestaw możliwy)
- Błędy walidacji wyświetlane w formularzu (LiveView changeset errors)
- Komunikaty w języku polskim, zrozumiałe
- Strategia nie zapisuje się dopóki wszystkie walidacje nie przejdą

### US-026: Obsługa długo działających symulacji

Tytuł: Kontynuacja symulacji po zamknięciu przeglądarki

Opis:
Jako użytkownik który uruchomił symulację
Chcę móc zamknąć przeglądarkę
Aby symulacja działała w tle i widzieć wynik gdy wrócę

Kryteria akceptacji:
- Symulacja uruchamiana w Task.async kontynuuje działanie na serwerze
- Zamknięcie przeglądarki nie przerywa symulacji
- Wynik zapisywany do bazy po zakończeniu (success/timeout/error)
- Po powrocie użytkownika:
  - Lista symulacji pokazuje status (running/success/timeout)
  - Najnowsze symulacje na górze
  - Jeśli symulacja wciąż działa: możliwość podłączenia do live trackingu
- Brak dedykowanej funkcji "wznowienia trackingu" - wystarczy kolejność wyświetlania

### US-027: Seed danych historycznych losowań

Tytuł: Przygotowanie bazy historycznych wyników Eurojackpot

Opis:
Jako administrator systemu
Chcę zasilić bazę danych historycznymi losowaniami
Aby użytkownicy mogli uruchamiać symulacje

Kryteria akceptacji:
- Migration/seed zawiera minimum 100-200 ostatnich losowań Eurojackpot
- Każde losowanie zawiera:
  - draw_date (unikalna data)
  - game_type: "eurojackpot"
  - numbers (JSONB): {"main_numbers": [x,x,x,x,x], "euro_numbers": [x,x]}
- Dane publicznie dostępne, ręcznie przygotowane
- Losowania posortowane chronologicznie
- Brak duplikatów dat
- Struktura uniwersalna (przygotowana na inne gry w przyszłości)

### US-028: Aktualizacja danych historycznych

Tytuł: Dodawanie nowych wyników losowań

Opis:
Jako administrator systemu
Chcę móc dodać wynik najnowszego losowania
Aby użytkownicy mieli aktualne dane

Kryteria akceptacji:
- Dodawanie przez seeding/migrations (brak admin UI w MVP1)
- Aktualizacja ręczna ~1x w tygodniu po losowaniu
- Walidacja przy zapisie:
  - Data jest unikalna
  - 5 głównych liczb w zakresie 1-50
  - 2 euro liczby w zakresie 1-12
  - Brak duplikatów liczb w obrębie zestawu
- Post-MVP: możliwość automatycznego scrapingu/API

### US-029: Obliczanie performance_score dla strategii

Tytuł: Automatyczna kalkulacja skuteczności strategii

Opis:
Jako system
Chcę automatycznie aktualizować performance_score strategii
Aby użytkownicy widzieli aktualną skuteczność

Kryteria akceptacji:
- Performance_score to mediana liczby prób ze wszystkich symulacji strategii
- Mediana obliczana zamiast średniej (mniej wrażliwa na outliery)
- Przeliczanie po każdej nowej symulacji dla danej strategii
- Strategie bez symulacji mają performance_score: NULL
- Wyświetlanie w rankingu i na liście strategii
- Używane do sortowania w rankingu (rosnąco - niższe = lepsze)

### US-030: Analiza gorących i zimnych liczb

Tytuł: Identyfikacja najczęściej i najrzadziej losowanych liczb

Opis:
Jako system przygotowujący dane dla AI
Chcę analizować częstotliwość wylosowania liczb
Aby AI mogło uwzględnić gorące/zimne liczby w strategii

Kryteria akceptacji:
- System analizuje ostatnie N losowań (domyślnie 32)
- Dla głównych liczb (1-50):
  - Zliczanie częstotliwości każdej liczby
  - Identyfikacja top X jako "gorące" (najczęstsze)
  - Identyfikacja bottom X jako "zimne" (najrzadsze)
- Analogicznie dla euro liczb (1-12)
- Wyniki przekazywane w prompcie do AI
- Dane używane przez strategie typu "hot_numbers" i "cold_numbers"

### US-031: Izolacja danych użytkowników

Tytuł: Zabezpieczenie przed dostępem do cudzych danych

Opis:
Jako użytkownik systemu
Chcę mieć pewność że widzę tylko swoje dane
Aby zachować prywatność moich strategii i wyników

Kryteria akceptacji:
- Wszystkie queries w aplikacji scopowane po user_id
- Użytkownik A nie może:
  - Zobaczyć strategii użytkownika B
  - Zobaczyć symulacji użytkownika B
  - Edytować/usunąć strategii użytkownika B
- Próba dostępu do cudzych danych przez manipulację URL zwraca 404 lub 403
- Testy jednostkowe weryfikujące izolację
- Dane historyczne (draws) są wspólne dla wszystkich

### US-032: Disclaimer prawny w aplikacji

Tytuł: Informacja o edukacyjnym charakterze

Opis:
Jako właściciel aplikacji
Chcę wyświetlić disclaimer prawny
Aby jasno zakomunikować że aplikacja nie gwarantuje wygranej

Kryteria akceptacji:
- Disclaimer widoczny na landing page
- Treść: "Aplikacja służy wyłącznie celom edukacyjnym i symulacyjnym. Nie gwarantuje wygranej i nie jest oficjalnie powiązana z operatorami loterii. Używaj na własną odpowiedzialność."
- Disclaimer również w stopce (footer) po zalogowaniu
- Jasne, czytelne formatowanie

### US-033: Responsive design dla urządzeń mobilnych

Tytuł: Adaptacja interfejsu do małych ekranów

Opis:
Jako użytkownik korzystający z telefonu
Chcę móc używać aplikacji na urządzeniu mobilnym
Aby mieć dostęp do strategii i symulacji w dowolnym miejscu

Kryteria akceptacji:
- Layout responsive (Bootstrap/Tailwind)
- Na mobile:
  - Nawigacja jako hamburger menu
  - Formularze w jednej kolumnie
  - Kupony (kule z numerami) układane pionowo
  - Listy (strategie, symulacje) czytelne
  - Przyciski dostatecznie duże do kliknięcia palcem
- Testowane na viewport: 320px (iPhone SE) do 1920px (desktop)
- Brak dedykowanych aplikacji iOS/Android w MVP

### US-034: Formatowanie wyników symulacji w JSON

Tytuł: Zapisywanie szczegółów trafień

Opis:
Jako system
Chcę zapisać szczegółowe informacje o wyniku symulacji
Aby użytkownik mógł zobaczyć dokładnie co zostało trafione

Kryteria akceptacji:
- Pole result w tabeli simulations (JSONB)
- Struktura dla success:
  ```
  {
    "matched_main": [1, 7, 23, 34, 50],
    "matched_euro": [3, 9],
    "attempts_count": 125430,
    "final_draw": {
      "main_numbers": [1, 7, 23, 34, 50],
      "euro_numbers": [3, 9]
    }
  }
  ```
- Struktura dla timeout:
  ```
  {
    "reason": "timeout",
    "limit_reached": "max_attempts" | "time_limit",
    "attempts_count": 1000000
  }
  ```
- Wyświetlanie szczegółów w UI w czytelnej formie

### US-035: Logowanie eventów dla analytics

Tytuł: Śledzenie kluczowych akcji użytkowników

Opis:
Jako właściciel produktu
Chcę śledzić podstawowe metryki użycia
Aby zrozumieć jak użytkownicy korzystają z aplikacji

Kryteria akceptacji:
- Logowanie do bazy (prosta tabela events):
  - user_id
  - event_type (enum: strategy_created, simulation_started, coupons_generated, etc.)
  - metadata (JSONB) - dodatkowe dane
  - inserted_at
- Nie używamy zewnętrznych narzędzi (Google Analytics, Mixpanel) w MVP1
- Logowane eventy:
  - Utworzenie strategii (manual vs ai_generated)
  - Uruchomienie symulacji
  - Wygenerowanie kuponów
  - Utworzenie miksu
- Możliwość prostych analiz przez SQL queries

## 6. Metryki sukcesu

### 6.1 Kryteria sukcesu funkcjonalnego

Aplikacja będzie uznana za sukces funkcjonalny gdy:

- Użytkownik może założyć konto i zalogować się poprawnie
- Użytkownik może wykonać pełny CRUD na strategiach (utworzyć, edytować, usunąć, przeglądać)
- Użytkownik może stworzyć strategię ręcznie LUB otrzymać strategię wygenerowaną przez AI
- Użytkownik może uruchomić pojedynczą symulację na wybranej strategii i jednym historycznym losowaniu
- Użytkownik może uruchomić multisymulację (3-10 równoległych symulacji) na różnych historycznych losowaniach (MVP2)
- Symulacje mają limity (timeout LUB max liczba prób) i nie trwają w nieskończoność
- Użytkownik widzi w czasie rzeczywistym postęp symulacji (liczba prób) przez LiveView
- Wynik każdej symulacji (liczba prób, czas, status: sukces/timeout) jest zapisany w bazie danych
- Dashboard wyświetla ranking pojedynczych strategii (najskuteczniejsze według mediany liczby prób)
- Dashboard wyświetla ranking mixów strategii po multisymulacjach
- Użytkownik może wygenerować propozycje liczb na najbliższe losowanie bazując na najlepszych strategiach

### 6.2 Kryteria sukcesu wydajnościowego

6.2.1 Skuteczność strategii
- Metryka: % symulacji zakończonych sukcesem (trafienie 5+2) w limicie prób
- Target: Minimum 50%
- Sposób mierzenia: COUNT(status='success') / COUNT(*) w tabeli simulations

6.2.2 Czas wykonania symulacji
- Metryka: Średni czas symulacji
- Target: Multisymulacja na 5 losowaniach kończy się w <2 minuty
- Sposób mierzenia: AVG(duration_seconds) w tabeli simulations dla multisymulacji

6.2.3 Stabilność systemu
- Metryka: % symulacji zakończonych bez błędów
- Target: >95% symulacji bez statusu "error"
- Sposób mierzenia: COUNT(status!='error') / COUNT(*) w tabeli simulations

6.2.4 Egzekwowanie limitów
- Metryka: Czy timeout enforcement działa poprawnie
- Target: 100% symulacji kończy się w ≤300s lub przy ≤1M prób
- Sposób mierzenia: MAX(duration_seconds) <= 300 AND MAX(attempts_count) <= 1000000

### 6.3 Kryteria sukcesu produktowego

6.3.1 Adopcja AI
- Metryka: Liczba strategii wygenerowanych przez AI vs manual
- Target: >60% strategii to ai_generated
- Sposób mierzenia: COUNT WHERE type='ai_generated' / COUNT(*) w tabeli strategies

6.3.2 Engagement użytkowników
- Metryka: Liczba symulacji na użytkownika
- Target: Średnio >5 symulacji/user w pierwszym tygodniu
- Sposób mierzenia: AVG(COUNT simulations per user_id)

6.3.3 Poprawa skuteczności iteracyjna
- Metryka: Czy nowe strategie AI są lepsze od starszych
- Target: Mediana prób dla strategii AI maleje w czasie
- Sposób mierzenia: Analiza performance_score vs inserted_at dla ai_generated strategies

6.3.4 Wykorzystanie generatora
- Metryka: % użytkowników generujących propozycje kuponów
- Target: >40% użytkowników użyje generatora
- Sposób mierzenia: Event logging - COUNT DISTINCT user_id WHERE event_type='coupons_generated' / COUNT DISTINCT user_id

6.3.5 Retencja strategii
- Metryka: Średnia liczba strategii na aktywnego użytkownika
- Target: >3 strategie/user
- Sposób mierzenia: AVG(COUNT strategies per user_id WHERE user has simulations)

### 6.4 Kryteria sukcesu edukacyjnego

Jako projekt zaliczeniowy dla kursu 10xdevs, aplikacja ma demonstrować:

6.4.1 Phoenix LiveView
- Real-time updates bez przeładowania strony
- Single Page Application w jednym LiveView component
- Efektywna komunikacja server-client przez LiveView messaging
- Demonstracja pub/sub patterns

6.4.2 Integracja AI
- Strukturalne promptowanie z kontekstem
- Walidacja i parsowanie JSON z odpowiedzi AI
- Iteracyjne doskonalenie strategii na podstawie feedbacku
- Obsługa błędów API gracefully

6.4.3 Elixir concurrency
- Task.async dla równoległych symulacji
- Proper timeout handling
- Process isolation i fault tolerance
- GenServer patterns dla długo działających procesów

6.4.4 Czysty kod i architektura
- Separation of concerns (Context pattern Phoenix)
- Testowalna logika biznesowa
- DRY principles
- Czytelna dokumentacja

### 6.5 Metody pomiaru i monitorowania

6.5.1 Monitoring techniczny
- Logi aplikacji (Elixir Logger)
- Analiza tabeli simulations (SQL queries)
- Monitoring performance_score w czasie

6.5.2 Analytics użytkowników
- Tabela events z logowaniem akcji
- Podstawowe SQL queries dla KPI
- Dashboard analytics (post-MVP)

6.5.3 Feedback użytkowników
- Proste formularze feedback (post-MVP)
- Monitoring błędów zgłaszanych przez użytkowników
- Obserwacja wzorców użycia

6.5.4 Testy jednostkowe
- ExUnit tests dla logiki biznesowej
- Pokrycie kluczowych funkcji:
  - Generowanie liczb zgodnie ze strategią
  - Porównywanie z targetem
  - Obliczanie mediany/performance_score
  - Walidacje strategii
- CI/CD automatycznie uruchamia testy (GitHub Actions)

### 6.6 Harmonogram ewaluacji

Tydzień 3:
- Pierwszy checkpoint: działający CRUD strategii
- Metryka: możliwość utworzenia minimum 5 różnych strategii manualnie

Tydzień 4:
- Drugi checkpoint: integracja AI
- Metryka: >80% requestów AI zwraca poprawny JSON

Tydzień 5:
- Trzeci checkpoint: działający silnik symulacji
- Metryka: >90% symulacji kończy się z statusem success lub timeout (nie error)

Tydzień 6 (koniec MVP1):
- Finalny checkpoint: wszystkie funkcje MVP1
- Metryki: wszystkie kryteria sukcesu funkcjonalnego spełnione

Post-MVP1 (MVP2):
- Ewaluacja po 2 tygodniach użytkowania
- Analiza wszystkich KPI produktowych
- Decyzja o dalszym rozwoju (multisymulacje, inne gry, zaawansowana analiza)

