# Podsumowanie Planowania PRD - Numbers Evolution

## Decyzje Projektowe

### 1. Model biznesowy i cel projektu
Projekt jest realizowany jako zaliczeniowy w ramach kursu 10xdevs. Nie ma planów monetyzacji. Aplikacja będzie całkowicie darmowa bez limitów dla użytkowników.

### 2. Grupa docelowa użytkowników
Zdefiniowano dwie główne persony:
- **Persona 1 "Analityk Tomek"** - entuzjasta statystyki i danych, lubi analizować wzorce
- **Persona 2 "Gracz Marek"** - regularny gracz Eurojackpot, chce testować różne strategie typowania

### 3. Rola AI w systemie
AI ma być centralnym elementem aplikacji odpowiedzialnym za:
- Generowanie strategii na podstawie promptów użytkownika i danych historycznych
- Uwzględnianie wskazówek strategicznych (z pliku REMOVE/chat)
- Tworzenie mixów rozwiązań
- Proponowanie nowych strategii zwiększających skuteczność
- **Główny cel**: dobieranie strategii minimalizujących liczbę prób do trafienia stopnia I (5+2)

### 4. Architektura techniczna
- Stack: Elixir/Phoenix LiveView
- Baza danych: PostgreSQL
- Równoległość: Task.async dla symulacji (do 10 równocześnie)
- Autoryzacja: Phoenix `mix phx.gen.auth` (email/hasło)
- AI Provider: OpenAI GPT-4 Turbo lub Claude 3.5 Sonnet
- Deployment: Fly.io (zakładane)

### 5. Podział na fazy MVP

**MVP1 (Core - 6 tygodni):**
1. Setup projektu + model danych (tydzień 1-2)
2. CRUD strategii (tydzień 3)
3. AI generowanie strategii (tydzień 4)
4. Pojedyncza symulacja + silnik (tydzień 5)
5. LiveView tracking + ranking (tydzień 6)
6. Generator propozycji (tydzień 6)
7. Autoryzacja i polishing (pod koniec MVP1)

**MVP2 (Enhanced - później):**
- Import danych historycznych (API/scraping)
- Multisymulacje równoległe
- Mixy strategii
- Zaawansowany ranking mixów
- Live tracking zaawansowany

### 6. Struktura danych - kluczowe tabele

**users**
- Standardowy schemat z `mix phx.gen.auth`
- Email/hasło, timestamps

**strategies**
- id (UUID)
- user_id (FK)
- name (string)
- type (enum: manual, ai_generated)
- ai_prompt (text, nullable)
- rules (JSONB) - struktura z wagami dla main_numbers i euro_numbers
- performance_score (float, nullable)
- inserted_at, updated_at

**draws** (uniwersalna nazwa, nie eurojackpot_draws)
- id (UUID)
- draw_date (date, unique)
- game_type (string) - "eurojackpot", przygotowanie na przyszłe gry
- numbers (JSONB) - elastyczna struktura: `{"main_numbers": [...], "euro_numbers": [...]}`
- inserted_at, updated_at

**simulations**
- id (UUID)
- user_id (FK)
- strategy_id (FK) - bez strategy_mix_id w MVP1
- target_draw_id (FK)
- attempts_count (integer)
- duration_seconds (float)
- status (enum: success, timeout, error)
- result (JSONB) - matched numbers
- inserted_at

### 7. Mechanika strategii i mixów

**Pojedyncza strategia:**
Przechowuje reguły w JSONB z wagami dla różnych kryteriów:
- even_odd_ratio: [2, 3] - 2 parzyste, 3 nieparzyste
- low_high_ratio: [2, 3] - 2 z 1-25, 3 z 26-50
- hot_numbers: [7, 19, 23] - preferowane gorące
- cold_numbers: [11, 34] - preferowane zimne
- weights: {"hot": 0.6, "cold": 0.2, "random": 0.2}

**Mix strategii (MVP1):**
Zamiast osobnej tabeli `strategy_mixes`, mixy tworzone są jako **nowe strategie** które łączą reguły składowych. Przykład: strategia "tylko nieparzyste" + "tylko 20-40" = nowa strategia pilnująca obu zasad lub zbliżona kompromisowa.

### 8. Proces generowania strategii przez AI

**Przepływ:**
1. User wprowadza prompt tekstowy
2. System zbiera ostatnie 32 losowania z tabeli draws
3. System analizuje gorące/zimne liczby
4. System tworzy strukturalny prompt zawierający:
   - Dane historyczne (32 losowania)
   - Wskazówki strategiczne (z pliku REMOVE/chat)
   - Skuteczność poprzednich strategii użytkownika
   - Instrukcję użytkownika
5. AI generuje odpowiedź w formacie JSON z polami: strategy_name, description, rules, reasoning, game_type
6. System waliduje JSON
7. System zapisuje strategię do bazy

**Obsługa błędów:**
- Jeśli AI zwróci błąd: wyświetlenie informacji o niepowodzeniu (bez fallback do strategii losowej)

### 9. Proces symulacji

**Input:**
- strategy_id (bez strategy_mix_id w MVP1)
- target_draw_id (historyczne losowanie do odgadnięcia)
- limits: max_attempts (default: 1M), timeout_seconds (default: 300)

**Proces:**
1. Task/proces generuje liczby zgodnie z regułami strategii w pętli
2. Po każdej generacji porównuje z target_draw (sprawdza czy 5+2)
3. Co 2 sekundy wysyła update do LiveView z licznikiem prób
4. Kończy gdy: trafiono 5+2 LUB osiągnięto limit prób LUB timeout

**Output do tabeli simulations:**
- attempts_count (ile prób było potrzebnych)
- duration_seconds (czas trwania)
- status (success/timeout/error)
- result (JSON z matched numbers)

### 10. UI/UX - Single Page Application w LiveView

**Architektura interfejsu:**
- Jedna strona główna (homepage `/`) obsługująca całość w LiveView
- Sekcje pojawiające się/ukrywane na klik po zalogowaniu
- **Nie używać** `/dashboard` (zajęty w Phoenix)
- Dynamiczne ładowanie komponentów bez przeładowania strony

**Kluczowe sekcje:**
1. Landing (przed logowaniem) - opis + CTA login/register
2. Dashboard (po logowaniu):
   - Statystyki użytkownika
   - Quick actions
3. Zarządzanie strategiami:
   - Lista strategii (CRUD)
   - Formularz nowy: Tab "Manualna" + Tab "AI"
   - Widok szczegółów strategii
4. Symulacje:
   - Formularz uruchomienia
   - Live tracking (licznik prób co 2s, czas, status)
   - Historia wyników
5. Ranking strategii (wg mediany prób - główna metryka MVP1)
6. Generator propozycji na losowanie

**Live tracking symulacji - MVP1:**
- Licznik prób (aktualizacja co 2 sekundy)
- Czas trwania
- Status (running/success/timeout)
- **Brak** przycisku Stop w MVP1

### 11. Generator propozycji na losowanie

**Algorytm:**
1. System znajduje top 3 strategie użytkownika wg mediany prób
2. Jeśli brak symulacji: oferuje wygenerowanie nowej strategii przez AI
3. User wybiera: ile kuponów (1-10) i którą strategię użyć
4. System generuje N zestawów 5+2 zgodnie z regułami strategii
5. Walidacja: żadne dwa kupony nie są identyczne

**UI:**
- Kupony wyświetlone jako wizualne "kule" z numerami
- Opcja "Wylosuj inne" (regeneracja)
- **Brak** exportu do pliku w MVP1
- **Brak** przycisku "Kopiuj wszystkie" w MVP1

### 12. Dane historyczne losowań

**Źródło danych MVP1:**
- Seed z ostatnimi 100-200 losowaniami jako fixtures
- Dane publicznie dostępne do ręcznego przygotowania
- Aktualizacja: ręczna przez admin panel (1x w tygodniu)

**Post-MVP:**
- Web scraping lub API integracja
- Automatyczny scheduler (np. co poniedziałek po losowaniu)

### 13. Metryki sukcesu

**Główna metryka rankingu strategii:**
- Mediana liczby prób (mniej wrażliwa na outliery niż średnia)

**KPI do monitorowania:**
- **Engagement:** Liczba strategii utworzonych przez AI, liczba uruchomionych symulacji
- **Feature adoption:** % poprawy skuteczności - jak bardziej efektywna jest aktualna wersja AI od poprzedniej (mniej prób do trafienia)
- **Technical:** Średni czas symulacji, współczynnik timeout/success, obciążenie serwera

**Analytics:**
- Podstawowe logowanie eventów do bazy (bez zewnętrznych narzędzi w MVP1)

### 14. Bezpieczeństwo i compliance

**Disclaimer prawny:**
Dodanie jasnego disclaimera w MVP1, że aplikacja służy wyłącznie celom edukacyjnym i symulacyjnym, nie gwarantuje wygranej i nie jest oficjalnie powiązana z operatorami loterii.

**Autoryzacja:**
- Wytyczne będą zaktualizowane przy osobnym zadaniu
- Implementacja pod koniec MVP1
- Każdy user widzi tylko swoje dane (scope w queries)
- Może być jeden hardcoded admin do seedowania

### 15. Kryteria sukcesu MVP1

**Funkcjonalne:**
- [ ] User może się zarejestrować i zalogować
- [ ] User może utworzyć strategię manualnie (formularz z parametrami)
- [ ] User może wygenerować strategię przez AI (prompt tekstowy)
- [ ] User może uruchomić pojedynczą symulację i zobaczyć wynik
- [ ] System śledzi TYLKO główną wygraną (5+2), nie inne stopnie
- [ ] User widzi ranking swoich strategii wg mediany prób
- [ ] User może wygenerować propozycje kuponów na następne losowanie

**Wydajnościowe:**
- Minimum 50% symulacji kończy się sukcesem (trafienie 5+2) w limicie prób
- Symulacje mają twarde limity (timeout 300s LUB max 1M prób)

**Timeline:**
- 6 tygodni na MVP1 z pomocą AI w kodowaniu

### 16. Autoryzacja - szczegóły implementacji

**Zakres MVP1:**
- Prosta rejestracja email/hasło bez walidacji siły hasła
- Brak potwierdzenia email przy rejestracji
- Brak funkcji resetowania hasła
- Login/Logout standard Phoenix auth
- OAuth nie planowany (ani w MVP ani w przyszłości)

**Implementacja pod koniec MVP1:**
Autoryzacja zostanie dodana w ostatniej fazie, co pozwala skupić się najpierw na core functionality.

### 17. Deployment i CI/CD

**MVP1 (lokalne środowisko):**
- Rozwój i testowanie lokalnie
- Brak wymagań produkcyjnych w pierwszej fazie
- Brak wykupywania domeny

**Post-MVP1:**
- Deployment na Fly.io
- Konfiguracja CI/CD na GitHub Actions:
  - Automatyczne uruchamianie testów przy każdym push/PR
  - Deployment automatyczny po merge do main (opcjonalnie)

### 18. Mix strategii - mechanika szczegółowa

**Rozwiązywanie konfliktów:**
- Jeśli reguły strategii są sprzeczne (np. jedna wymaga parzyste, druga nieparzyste), system wyświetla komunikat o konflikcie
- Strategia z wyższym performance_score (skuteczniejsza) ma priorytet
- **Cel mixu:** podkręcanie skuteczności poprzez łączenie najlepszych aspektów

**Rola użytkownika vs AI:**
- User NIE dostaje interfejsu do manualnej edycji wynikowego miksu
- AI działa jako ekspert w tworzeniu mixów
- AI analizuje składowe strategie i generuje nową z optymalną kombinacją reguł

### 19. Obsługa błędów AI

**Format prezentacji błędu:**
- Czerwony komunikat o niepowodzeniu widoczny dla użytkownika
- Wyświetlenie szczegółów debugowania błędu (np. timeout API, invalid JSON)
- Ustawienie odpowiedniego statusu przy zapisie próby generowania

**Interakcja użytkownika:**
- Przycisk "Spróbuj ponownie" (retry) z tym samym promptem
- Brak automatycznych sugestii jak poprawić prompt (user sam decyduje o zmianach)

### 20. Koszty API i optymalizacja

**MVP1 - bez optymalizacji:**
- Brak cache'owania odpowiedzi AI dla podobnych promptów
- Brak rate limiting dla generowania strategii
- Proste wywołania API bez dodatkowych warstw

**Uzasadnienie:**
Dla projektu zaliczeniowego prostota > optymalizacja. Można dodać te funkcje post-MVP jeśli koszty API staną się problemem.

### 21. Admin panel

**Decyzja MVP1:**
Admin panel jest **niepotrzebny** w MVP1.

**Konsekwencje:**
- Dane historyczne (losowania) dodawane przez seeding/migrations
- Brak interfejsu do zarządzania użytkownikami
- Rozwój aplikacji może dodać admin funkcje post-MVP jeśli potrzebne

### 22. Rozszerzalność na inne gry losowe

**MVP1 - tylko Eurojackpot:**
- Implementacja skupiona wyłącznie na Eurojackpot
- Architektura projektowana z myślą o łatwej rozbudowie

**Przygotowanie na przyszłość:**
- Strategie mają pole `game_type` (może być "eurojackpot" lub "universal")
- Strategie uniwersalne (np. parzystość) działają niezależnie od gry
- Strategie specyficzne (np. hot numbers dla konkretnej gry) przypisane do game_type
- Struktura tabeli `draws` umożliwia różne typy gier (pole `game_type` + JSONB `numbers`)

**Post-MVP gry do rozważenia:**
- Multi Multi
- Lotto
- Keno

### 23. Walidacja strategii

**Moment walidacji:**
Walidacja wykonywana **przy zapisie strategii**, nie przed symulacją.

**Sprawdzenia:**
- Czy strategia poprawnie skonfigurowana dla wybranego typu gry
- Czy reguły są matematycznie poprawne (np. wagi sumują się do 1.0)
- Czy strategia może generować różne zestawy liczb
- Strategie uniwersalne: sprawdzenie czy mogą działać z różnymi grami

**Feedback dla użytkownika:**
Komunikaty walidacji w formularzu przed zapisem (LiveView changeset errors).

### 24. Handling symulacji w tle

**Zachowanie przy zamknięciu przeglądarki:**
- Symulacja kontynuuje działanie na serwerze w tle
- Proces Task.async nie jest przerywany
- Wynik zapisywany do bazy po zakończeniu (success/timeout)

**UX po powrocie użytkownika:**
- Brak dedykowanej funkcji "wznowienia trackingu"
- Kolejność wyświetlania symulacji (najnowsze na górze) daje znać co było ostatnio uruchomione
- Status symulacji widoczny na liście (running/success/timeout)

### 25. Strategia testowania

**Pokrycie testami:**
- **Unit testy:** Logika biznesowa pokryta ExUnit tests
  - Generowanie liczb zgodnie ze strategią
  - Porównywanie z targetem
  - Obliczanie mediany/performance_score
  - Walidacje strategii
- **Brak testów integracyjnych:** LiveView i AI API nie testowane automatycznie (koszty, złożoność)

**CI/CD:**
- GitHub Actions automatycznie uruchamia testy przy każdym push/PR
- Pipeline musi przejść zanim merge do main

**Testy manualne:**
- LiveView UI testowane ręcznie podczas development
- Integracja z AI testowana ręcznie z prawdziwymi API calls

---

## Dopasowane Rekomendacje

### Rekomendacja 1: Architektura bez osobnej tabeli strategy_mixes
**Decyzja:** Zamiast tworzyć osobny byt i tabelę dla mixów, system będzie generował nowe strategie które łączą reguły składowych. To upraszcza model danych i logikę aplikacji w MVP1.

### Rekomendacja 2: Uniwersalna tabela draws
**Decyzja:** Nazwa tabeli zmieniona z `eurojackpot_draws` na `draws` z polem `game_type`, co przygotowuje aplikację na obsługę innych gier losowych w przyszłości (Multi Multi, Lotto, Keno).

### Rekomendacja 3: Elixir conventions dla timestampów
**Decyzja:** Używanie domyślnych Elixir/Ecto timestampów: `inserted_at`, `updated_at` zamiast wymyślanych nazw jak `created_at`.

### Rekomendacja 4: Minimalny UI dla symulacji w MVP1
**Decyzja:** Ograniczenie live trackingu do trzech podstawowych elementów (licznik prób co 2s, czas, status) bez przycisku Stop, ETA czy wykresów. Upraszcza to implementację pierwszej wersji.

### Rekomendacja 5: Single Page Application w LiveView
**Decyzja:** Całość jako SPA na jednej stronie głównej z dynamicznie ładowanymi sekcjami, co lepiej wykorzystuje możliwości LiveView i poprawia UX.

### Rekomendacja 6: Brak fallbacku do losowej strategii
**Decyzja:** Jeśli AI zawiedzie, system pokazuje błąd zamiast generować zastępczą strategię losową. Zapobiega to tworzeniu strategii niskiej jakości.

### Rekomendacja 7: Większy kontekst historyczny dla AI (32 losowania)
**Decyzja:** Zwiększenie z 20 do 32 ostatnich losowań przekazywanych do AI, co daje lepszy materiał do analizy wzorców przy akceptowalnym koszcie tokensów.

### Rekomendacja 8: Uwzględnianie skuteczności poprzednich strategii
**Decyzja:** Prompt dla AI ma zawierać informację o skuteczności wcześniejszych strategii użytkownika, umożliwiając iteracyjne doskonalenie.

### Rekomendacja 9: Mediana jako główna metryka
**Decyzja:** Ranking strategii bazuje na medianie liczby prób (zamiast średniej), co jest bardziej odporne na ekstremalne wartości i lepiej reprezentuje typową skuteczność.

### Rekomendacja 10: Autoryzacja na końcu MVP1
**Decyzja:** Przesunięcie implementacji logowania i rejestracji pod koniec fazy MVP1, co pozwala skupić się najpierw na core functionality (strategie, symulacje, AI).

### Rekomendacja 11: Minimalistyczna autoryzacja bez nadmiarowych funkcji
**Decyzja:** Rezygnacja z potwierdzenia email, resetowania hasła i OAuth w MVP. Prostota implementacji przyspiesza development i jest wystarczająca dla projektu zaliczeniowego.

### Rekomendacja 12: Deployment progresywny (lokalne → Fly.io)
**Decyzja:** Rozpoczęcie od środowiska lokalnego, deployment produkcyjny dopiero post-MVP. To pozwala skupić się na funkcjonalności bez marnowania czasu na infrastrukturę w fazie rozwoju.

### Rekomendacja 13: AI jako ekspert w tworzeniu mixów
**Decyzja:** AI odpowiada za łączenie strategii, user nie edytuje mixu manualnie. Wykorzystuje to mocne strony AI w analizie i optymalizacji, upraszcza UI.

### Rekomendacja 14: Transparentne błędy z możliwością retry
**Decyzja:** Pokazywanie szczegółów błędów AI (zamiast ukrywania) + przycisk retry. Pomaga w debugowaniu i daje userowi kontrolę bez frustracji.

### Rekomendacja 15: Brak przedwczesnej optymalizacji API
**Decyzja:** Rezygnacja z cachowania i rate limiting w MVP. Zgodnie z zasadą "premature optimization is the root of all evil" - implementujemy to tylko gdy stanie się problemem.

### Rekomendacja 16: Seeding zamiast admin panelu
**Decyzja:** Dane historyczne przez migrations/seeding, brak admin UI. Oszczędza czas development na funkcje które nie są core dla projektu.

### Rekomendacja 17: Future-proof architektura bez overengineering
**Decyzja:** Struktura danych (`game_type`, `JSONB numbers`) przygotowana na rozbudowę, ale implementacja tylko Eurojackpot w MVP. Balans między elastycznością a prostotą.

### Rekomendacja 18: Wczesna walidacja (przy zapisie, nie przy użyciu)
**Decyzja:** Walidacja strategii przy tworzeniu/edycji, nie przed symulacją. Zasada "fail fast" - user dostaje feedback natychmiast, nie po uruchomieniu symulacji.

### Rekomendacja 19: Background processing z graceful degradation
**Decyzja:** Symulacje kontynuują w tle po zamknięciu przeglądarki, ale bez skomplikowanego "resume tracking". Użytkownik widzi wynik gdy wróci - proste i skuteczne.

### Rekomendacja 20: Pragmatyczne testowanie (unit > integration)
**Decyzja:** Fokus na unit testach logiki biznesowej, rezygnacja z kosztownych testów integracyjnych. W projekcie edukacyjnym ważniejsza jest demonstracja rozumienia niż 100% pokrycie.

---

## Szczegółowy Plan Rozwoju PRD

### Główne Wymagania Funkcjonalne

#### F1: Zarządzanie Strategiami
- **F1.1** CRUD strategii (Create, Read, Update, Delete)
- **F1.2** Tworzenie strategii manualnie poprzez formularz z parametrami:
  - Ratio parzyste/nieparzyste
  - Ratio low/high (1-25 vs 26-50)
  - Lista preferowanych gorących liczb
  - Lista preferowanych zimnych liczb
  - Wagi dla różnych kryteriów
- **F1.3** Generowanie strategii przez AI poprzez prompt tekstowy:
  - User wprowadza opis w języku naturalnym
  - System analizuje ostatnie 32 losowania
  - AI generuje strategię w formacie JSON
  - Walidacja i zapis do bazy
- **F1.4** Przechowywanie typu strategii (manual/ai_generated)
- **F1.5** Przechowywanie oryginalnego promptu dla strategii AI

#### F2: Silnik Symulacji
- **F2.1** Uruchamianie pojedynczej symulacji dla wybranej strategii
- **F2.2** Wybór historycznego losowania jako targetu
- **F2.3** Generowanie liczb zgodnie z regułami strategii w pętli
- **F2.4** Porównywanie z targetem (sprawdzanie czy 5+2)
- **F2.5** Śledzenie TYLKO głównej wygranej (5+2), ignorowanie innych stopni
- **F2.6** Twarde limity bezpieczeństwa:
  - Max 1M prób (default)
  - Timeout 300 sekund (default)
- **F2.7** Zapis wyniku do bazy (attempts_count, duration, status)

#### F3: Live Tracking w LiveView
- **F3.1** Real-time aktualizacja licznika prób (co 2 sekundy)
- **F3.2** Wyświetlanie czasu trwania symulacji
- **F3.3** Wyświetlanie statusu (running/success/timeout)
- **F3.4** Brak przycisku Stop w MVP1

#### F4: Ranking i Analiza
- **F4.1** Obliczanie mediany liczby prób dla każdej strategii
- **F4.2** Ranking strategii wg mediany (najniższa = najlepsza)
- **F4.3** Wyświetlanie performance_score dla strategii
- **F4.4** Historia wszystkich symulacji użytkownika

#### F5: Generator Propozycji
- **F5.1** Identyfikacja top 3 strategii użytkownika
- **F5.2** Wybór liczby kuponów (1-10)
- **F5.3** Wybór strategii do użycia
- **F5.4** Generowanie unikalnych zestawów 5+2
- **F5.5** Wizualizacja jako "kule" z numerami
- **F5.6** Opcja regeneracji ("Wylosuj inne")

#### F6: Dane Historyczne
- **F6.1** Seed z 100-200 ostatnimi losowaniami Eurojackpot
- **F6.2** Uniwersalna struktura obsługująca różne typy gier
- **F6.3** Ręczny admin panel do dodawania nowych losowań

#### F7: Autoryzacja (pod koniec MVP1)
- **F7.1** Rejestracja użytkownika (email/hasło)
- **F7.2** Login/Logout
- **F7.3** Zmiana hasła
- **F7.4** Izolacja danych między użytkownikami

#### F8: UI Single Page Application
- **F8.1** Landing page z opisem i CTA
- **F8.2** Dashboard po logowaniu z statystykami
- **F8.3** Sekcja zarządzania strategiami
- **F8.4** Sekcja uruchamiania symulacji
- **F8.5** Sekcja rankingu
- **F8.6** Sekcja generatora propozycji
- **F8.7** Wszystko na jednej stronie, dynamiczne przełączanie

### Kluczowe Historie Użytkownika

#### User Story Auth 1: Rejestracja Nowego Użytkownika
**Jako** nowy użytkownik systemu
**Chcę** móc się zarejestrować
**Aby** mieć dostęp do prywatnych funkcji aplikacji

**Kryteria akceptacji:**
- Formularz rejestracji z email + hasłem
- Walidacja formatu email
- Hasło minimum 12 znaków
- Automatyczne logowanie po rejestracji
- Przekierowanie na dashboard po rejestracji
- Obsługa błędów walidacji

#### User Story Auth 2: Logowanie do Systemu
**Jako** zarejestrowany użytkownik
**Chcę** móc się zalogować do systemu
**Aby** mieć dostęp do swoich danych i funkcji

**Kryteria akceptacji:**
- Formularz logowania z email + hasłem
- Pamiętanie sesji między przeglądarkami
- Automatyczne przekierowanie na dashboard
- Komunikat błędu przy nieprawidłowych danych
- Bezpieczne przechowywanie sesji (HttpOnly cookies)

#### User Story Auth 3: Wylogowanie z Systemu
**Jako** zalogowany użytkownik
**Chcę** móc się wylogować
**Aby** zabezpieczyć dostęp do mojego konta

**Kryteria akceptacji:**
- Przycisk wylogowania w nawigacji
- Czyszczenie sesji po wylogowaniu
- Przekierowanie na stronę główną
- Blokada dostępu do chronionych zasobów po wylogowaniu

#### User Story Auth 4: Izolacja Danych Użytkownika
**Jako** użytkownik systemu
**Chcę** widzieć tylko swoje dane
**Aby** zachować prywatność i bezpieczeństwo

**Kryteria akceptacji:**
- Wszystkie zapytania do bazy danych filtrowane po user_id
- Brak dostępu do danych innych użytkowników
- API wymaga prawidłowej autentyfikacji
- Próba dostępu bez autentyfikacji zwraca błąd 401

#### User Story Auth 5: Reset Hasła
**Jako** użytkownik systemu
**Chcę** móc zresetować hasło
**Aby** odzyskać dostęp do konta w przypadku zapomnienia hasła

**Kryteria akceptacji:**
- Link "zapomniałem hasła" na stronie logowania
- Wysyłanie email z linkiem resetującym
- Bezpieczny token jednorazowy ważny 24h
- Formularz zmiany hasła
- Automatyczne logowanie po zmianie hasła

#### User Story 1: Tworzenie strategii manualnie
**Jako** Analityk Tomek (persona 1)  
**Chcę** móc stworzyć strategię typowania ręcznie ustawiając parametry  
**Aby** przetestować własne intuicje dotyczące rozkładu liczb

**Kryteria akceptacji:**
- Mogę wypełnić formularz z parametrami strategii
- Mogę ustawić ratio parzyste/nieparzyste (np. 2:3)
- Mogę ustawić ratio low/high (np. 2:3)
- Mogę wybrać preferowane gorące liczby (analiza historyczna)
- Mogę wybrać preferowane zimne liczby
- Mogę ustawić wagi dla kryteriów
- Strategia zapisuje się z typem "manual"

#### User Story 2: Generowanie strategii przez AI
**Jako** Gracz Marek (persona 2)  
**Chcę** opisać słowami jaki typ strategii mnie interesuje  
**Aby** AI wygenerowało dla mnie parametry bez męczenia się z formularzem

**Kryteria akceptacji:**
- Mogę wprowadzić prompt tekstowy w języku naturalnym
- System analizuje ostatnie 32 losowania przed generacją
- AI zwraca strategię w formacie JSON z uzasadnieniem
- Strategia zapisuje się z typem "ai_generated" i oryginalnym promptem
- Jeśli AI zwróci błąd, widzę komunikat o niepowodzeniu

#### User Story 3: Uruchamianie symulacji
**Jako** użytkownik systemu  
**Chcę** uruchomić symulację dla mojej strategii na historycznym losowaniu  
**Aby** zobaczyć ile prób byłoby potrzebnych do trafienia głównej wygranej

**Kryteria akceptacji:**
- Mogę wybrać strategię z listy
- Mogę wybrać historyczne losowanie jako target
- Mogę (opcjonalnie) dostosować limity (max prób, timeout)
- Symulacja uruchamia się w tle (Task.async)
- Widzę live licznik prób (aktualizacja co 2s)
- Widzę czas trwania
- Widzę status (running/success/timeout)
- Symulacja zatrzymuje się gdy trafię 5+2 lub osiągnę limit
- Wynik zapisuje się w bazie z liczbą prób

#### User Story 4: Przeglądanie rankingu strategii
**Jako** użytkownik systemu  
**Chcę** zobaczyć ranking moich strategii według skuteczności  
**Aby** wiedzieć która działa najlepiej

**Kryteria akceptacji:**
- Widzę listę wszystkich moich strategii
- Lista posortowana wg mediany liczby prób (rosnąco)
- Dla każdej strategii widzę: nazwę, typ, medianę prób, liczbę symulacji
- Mogę kliknąć strategię aby zobaczyć szczegóły i historię symulacji

#### User Story 5: Generowanie propozycji kuponów
**Jako** Gracz Marek (persona 2)  
**Chcę** wygenerować propozycje liczb na następne losowanie  
**Aby** użyć ich do faktycznego zakupu kuponu

**Kryteria akceptacji:**
- Widzę top 3 moje najskuteczniejsze strategie
- Mogę wybrać którą strategię użyć
- Mogę wybrać ile kuponów wygenerować (1-10)
- System generuje unikalne zestawy 5+2
- Kupony wyświetlone jako wizualne "kule" z numerami
- Mogę kliknąć "Wylosuj inne" aby regenerować

#### User Story 6: Mix strategii
**Jako** Analityk Tomek (persona 1)  
**Chcę** połączyć dwie strategie (np. "tylko nieparzyste" + "tylko 20-40")  
**Aby** stworzyć hybrydę respektującą oba ograniczenia

**Kryteria akceptacji:**
- Mogę zaznaczyć 2-3 strategie jako składowe miksu
- System generuje nową strategię łączącą reguły
- Nowa strategia pilnuje zasad wszystkich składowych lub tworzy najbliższy kompromis
- Mix zapisany jako osobna strategia (bez dodatkowej tabeli)
- Mogę uruchomić symulację dla miksu jak dla zwykłej strategii

### Ważne Kryteria Sukcesu i Sposoby Mierzenia

#### Sukces Techniczny
1. **Stabilność symulacji**
   - Metryka: % symulacji zakończonych bez errorów
   - Target: >95%
   - Sposób mierzenia: Analiza pola `status` w tabeli simulations

2. **Skuteczność strategii**
   - Metryka: % symulacji zakończonych sukcesem (trafienie 5+2) w limicie
   - Target: >50%
   - Sposób mierzenia: COUNT(status='success') / COUNT(*) w simulations

3. **Wydajność**
   - Metryka: Średni czas symulacji
   - Target: Większość <2 minuty
   - Sposób mierzenia: AVG(duration_seconds) w simulations

4. **Limity bezpieczeństwa**
   - Metryka: Czy timeout enforcement działa
   - Target: 100% symulacji kończy się w <300s lub przy 1M prób
   - Sposób mierzenia: Monitoring duration_seconds, nie powinno być wartości >300

#### Sukces Produktowy
1. **Adopcja AI**
   - Metryka: Liczba strategii wygenerowanych przez AI vs manual
   - Target: >60% strategii to ai_generated
   - Sposób mierzenia: COUNT WHERE type='ai_generated' / COUNT(*) w strategies

2. **Engagement użytkowników**
   - Metryka: Liczba symulacji na użytkownika
   - Target: Średnio >5 symulacji/user w pierwszym tygodniu
   - Sposób mierzenia: AVG(COUNT simulations per user_id)

3. **Poprawa skuteczności iteracyjna**
   - Metryka: Czy nowe strategie AI są lepsze od starszych
   - Target: Mediana prób dla strategii AI maleje w czasie
   - Sposób mierzenia: Analiza performance_score vs inserted_at dla ai_generated strategies

4. **Wykorzystanie generatora**
   - Metryka: % użytkowników generujących propozycje kuponów
   - Target: >40% użytkowników użyje generatora
   - Sposób mierzenia: Event logging w bazie (tablica user_events lub similar)

#### Sukces Edukacyjny (cel projektu)
1. **Demonstracja możliwości Phoenix LiveView**
   - Real-time updates bez przeładowania strony
   - SPA w jednym LiveView component
   - Efektywna komunikacja server-client

2. **Demonstracja integracji AI**
   - Strukturalne promptowanie
   - Walidacja i parsowanie JSON z AI
   - Iteracyjne doskonalenie na podstawie feedbacku

3. **Demonstracja Elixir concurrency**
   - Task.async dla równoległych symulacji
   - Proper timeout handling
   - LiveView messaging dla progress updates

---

## Podsumowanie Uzupełnionych Decyzji

Wszystkie 10 pierwotnie nierozwiązanych kwestii zostało wyjaśnionych i włączonych do głównych decyzji projektowych (punkty 16-25 powyżej). Poniżej krótkie podsumowanie:

✅ **Kwestia 1 → Decyzja 16:** Autoryzacja prosta (email/hasło), bez potwierdzenia, resetowania, OAuth  
✅ **Kwestia 2 → Decyzja 17:** MVP lokalnie, później Fly.io + CI/CD GitHub Actions  
✅ **Kwestia 3 → Decyzja 18:** Mix konfliktów: priorytet skuteczniejszej strategii, AI tworzy mixy  
✅ **Kwestia 4 → Decyzja 19:** Błędy AI: czerwony komunikat + debug, retry możliwy  
✅ **Kwestia 5 → Decyzja 20:** Bez cachowania i rate limiting w MVP  
✅ **Kwestia 6 → Decyzja 21:** Admin panel niepotrzebny w MVP  
✅ **Kwestia 7 → Decyzja 22:** Tylko Eurojackpot w MVP, architektura rozszerzalna  
✅ **Kwestia 8 → Decyzja 23:** Walidacja przy zapisie strategii  
✅ **Kwestia 9 → Decyzja 24:** Symulacje w tle kontynuują, kolejność lista wystarczy  
✅ **Kwestia 10 → Decyzja 25:** Unit testy logiki, CI/CD auto-run, bez testów integracyjnych  

**Status planowania:** ✅ **KOMPLETNY** - wszystkie kwestie rozwiązane

---

## Następne Kroki

### 1. ✅ Review podsumowania
**Status:** UKOŃCZONE - wszystkie decyzje zatwierdzone

### 2. ✅ Wyjaśnienie nierozwiązanych kwestii  
**Status:** UKOŃCZONE - wszystkie 10 kwestii wyjaśnionych

### 3. 🎯 Stworzenie pełnego dokumentu PRD
**Status:** GOTOWE DO REALIZACJI  
**Działanie:** Generowanie formalnego PRD na podstawie tego podsumowania

### 4. 📋 Przygotowanie backlogu
**Działanie:** Konwersja user stories i funkcjonalności na konkretne taski w backlogu
- Rozbicie na sprinty/tygodnie (6-tygodniowy timeline)
- Priorytyzacja tasków
- Estymacja czasowa

### 5. 🚀 Setup projektu i rozpoczęcie development
**Działanie:** Inicjalizacja projektu według 6-tygodniowego planu:
- Week 1-2: Phoenix init, baza danych, podstawowy layout
- Week 3: Moduł strategii + CRUD
- Week 4: Integracja AI
- Week 5: Silnik symulacji
- Week 6: LiveView tracking, ranking, generator, autoryzacja

**Gotowość:** 🟢 Wszystkie informacje zebrane, można rozpocząć implementację

