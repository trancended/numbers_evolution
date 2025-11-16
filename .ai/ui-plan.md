# Architektura UI dla Numbers Evolution MVP

## 1. Przegląd struktury UI

Numbers Evolution to edukacyjna aplikacja webowa zbudowana jako Single Page Application (SPA) wykorzystująca Phoenix LiveView. Aplikacja umożliwia użytkownikom tworzenie, testowanie i analizę strategii typowania liczb w grze Eurojackpot.

### Architektura techniczna

**Framework**: Phoenix LiveView (real-time SPA bez JavaScript framework)  
**Styling**: Tailwind CSS v4 + DaisyUI  
**Ikony**: Heroicons  
**Komponenty**: Phoenix Function Components w `core_components.ex`

### Główne założenia architektoniczne

1. **Single Page Application na `/`**: Główny LiveView (`PageLive`) zarządza widocznością sekcji przez `@active_section` assign
2. **Nawigacja przez phx-click**: Przełączanie sekcji bez zmiany URL i przeładowania strony
3. **Autoryzacja przez on_mount**: Automatyczna weryfikacja `current_user` i odpowiednie przekierowania
4. **Real-time updates**: Phoenix PubSub dla live tracking symulacji
5. **Responsywny design**: Tailwind breakpoints dla desktop (>768px) i mobile (≤768px)

### Sekcje aplikacji

Aplikacja składa się z 6 głównych sekcji:
- **:landing** - strona powitalna dla niezalogowanych użytkowników
- **:dashboard** - centrum kontroli i statystyki użytkownika
- **:strategies** - zarządzanie strategiami (CRUD, AI generation, mixing)
- **:simulations** - uruchamianie i monitorowanie symulacji
- **:ranking** - ranking strategii według skuteczności
- **:generator** - generator propozycji liczb na losowanie

## 2. Lista widoków

### 2.1 Landing Page (Sekcja :landing)

**Ścieżka**: `/` (dla niezalogowanych użytkowników)

**Główny cel**: Przedstawienie aplikacji i zachęcenie do rejestracji/logowania

**Kluczowe informacje do wyświetlenia**:
- Nazwa aplikacji: "Numbers Evolution"
- Tagline: "Testuj strategie typowania Eurojackpot z pomocą AI"
- Główne funkcjonalności (bullet points):
  - Tworzenie strategii manualnie lub przez AI
  - Symulacje na danych historycznych
  - Ranking skuteczności strategii
  - Generator propozycji na losowanie
- Disclaimer prawny: "Aplikacja służy wyłącznie celom edukacyjnym i symulacyjnym. Nie gwarantuje wygranej i nie jest oficjalnie powiązana z operatorami loterii."

**Kluczowe komponenty widoku**:
- **Hero section**: Z nazwą aplikacji i tagline
- **Features list**: Lista głównych funkcjonalności z ikonami
- **CTA buttons**: Duże przyciski "Zarejestruj się" i "Zaloguj"
- **Footer**: Z disclaimerem prawnym

**UX, dostępność i względy bezpieczeństwa**:
- Semantyczny HTML: `<header>`, `<main>`, `<section>`, `<footer>`
- Jasny visual hierarchy z dużymi przyciskami CTA
- Kontrast kolorów zgodny z WCAG AA
- Przyciski z odpowiednimi aria-labels
- Responsywny layout: hero na całą szerokość na mobile, dwukolumnowy na desktop

---

### 2.2 Dashboard (Sekcja :dashboard)

**Ścieżka**: `/` (domyślna sekcja po zalogowaniu)

**Główny cel**: Szybki przegląd stanu konta i dostęp do głównych funkcji

**Kluczowe informacje do wyświetlenia**:
- **Powitanie użytkownika**: "Witaj, [email]"
- **Statystyki użytkownika**:
  - Liczba utworzonych strategii
  - Liczba przeprowadzonych symulacji
  - Najlepsza strategia (nazwa + mediana prób)
  - Data ostatniej aktywności
- **Ostatnie 5 symulacji**: Mini lista z nazwą strategii, target draw, liczbą prób, statusem

**Kluczowe komponenty widoku**:
- **Stats cards**: 4 karty DaisyUI z głównymi statystykami
- **Quick actions**: 3 duże przyciski akcji:
  - "Utwórz nową strategię" → przełącza na :strategies
  - "Uruchom symulację" → przełącza na :simulations
  - "Generuj propozycje" → przełącza na :generator
- **Recent simulations table**: Tabela DaisyUI z ostatnimi symulacjami, linkowanie do szczegółów przez modal

**UX, dostępność i względy bezpieczeństwa**:
- Quick actions jako primary buttons dla łatwej identyfikacji
- Statystyki w kartach z ikonami dla szybkiego skanowania
- Loading states dla statystyk (skeleton screens jeśli ładowanie >500ms)
- Dane ładowane przez Context modules z user_id scope
- Aria-labels dla kart statystyk
- Responsywny grid: 1 kolumna mobile, 2-4 kolumny desktop

---

### 2.3 Sekcja Strategii (Sekcja :strategies)

**Ścieżka**: `/` z `@active_section = :strategies`

**Główny cel**: Zarządzanie strategiami - przeglądanie, tworzenie, edycja, usuwanie, mieszanie

**Kluczowe informacje do wyświetlenia**:

#### Widok listy strategii:
- Tabela/karty wszystkich strategii użytkownika:
  - Nazwa strategii
  - Typ (manual/ai_generated) z badge
  - Performance score (mediana prób)
  - Liczba symulacji
  - Przyciski akcji: Zobacz szczegóły, Edytuj, Usuń

#### Formularz tworzenia strategii (taby):
**Tab "Manualna"**:
- Nazwa strategii (input text)
- **Główne liczby (1-50)**:
  - Ratio parzyste/nieparzyste (2 inputy number sumujące się do 5)
  - Ratio low/high (1-25 vs 26-50, 2 inputy sumujące się do 5)
  - Preferowane gorące liczby (multi-select lub textarea)
  - Preferowane zimne liczby (multi-select lub textarea)
  - Wagi (3 inputy: hot, cold, random - sumujące się do 1.0)
- **Euro liczby (1-12)**:
  - Ratio parzyste/nieparzyste (2 inputy sumujące się do 2)
  - Preferowane liczby (multi-select lub textarea)
  - Wagi (2 inputy: hot, random - sumujące się do 1.0)

**Tab "AI"**:
- Textarea na prompt (max 500 znaków z licznikiem)
- Przykłady promptów (collapsed accordion)
- Przycisk "Generuj strategię AI"
- Sekcja wyników (pokazuje się po kliknięciu):
  - Loading state z spinnerem i komunikatem
  - Sukces: wygenerowana strategia (nazwa, description, reasoning, rules czytelnie sformatowane)
  - Błąd: alert-error z komunikatem i przyciskiem "Spróbuj ponownie"

#### Mix strategii:
- Checkboxy przy każdej strategii na liście
- Przycisk "Utwórz mix" (aktywny gdy zaznaczone 2-3 strategie)
- Modal z procesem generowania miksu przez AI
- Wynik: nowa strategia do zapisu lub komunikat o konfliktach

**Kluczowe komponenty widoku**:
- **Strategies table/cards**: Tabela DaisyUI z sortowaniem, filtrowaniem
- **Create strategy button**: Primary button "Nowa strategia" otwierający formularz
- **Strategy form modal/section**: Formularz z tabami (DaisyUI tabs)
- **AI generation section**: Loading overlay, alert components
- **Mix modal**: Modal DaisyUI z loading state i wynikami
- **Strategy details modal**: Modal z pełnymi informacjami, historią symulacji, akcjami
- **Pagination**: DaisyUI join z przyciskami numerów stron (20 strategii na stronę)

**UX, dostępność i względy bezpieczeństwa**:
- Walidacja formularza w real-time (changeset errors inline)
- Suma wag i ratio pokazana dynamicznie (live update)
- Loading states dla operacji AI (spinner + komunikat)
- Błędy walidacji przy polach (DaisyUI label-text z text-error)
- Potwierdzenie przed usunięciem strategii (modal "Czy na pewno?")
- Checkboxy z aria-labels dla miksowania
- Rate limiting UI: komunikat "Możesz wygenerować 5 strategii przez AI dziennie"
- Dane strategii scope'owane po user_id
- Responsywne: tabela → karty na mobile, formularz w jednej kolumnie

---

### 2.4 Sekcja Symulacji (Sekcja :simulations)

**Ścieżka**: `/` z `@active_section = :simulations`

**Główny cel**: Uruchamianie symulacji i monitorowanie wyników

**Kluczowe informacje do wyświetlenia**:

#### Formularz uruchomienia symulacji:
- Wybór strategii (dropdown/select z listą strategii użytkownika)
- Wybór target draw (dropdown z datami historycznych losowań)
- Opcjonalne limity (collapsible section):
  - Max liczba prób (input number, default: 1,000,000)
  - Timeout w sekundach (input number, default: 300)
- Przycisk "Uruchom symulację"

#### Live tracking (:simulation_tracking podsekcja):
- **Duży licznik prób**: Centralnie, dużą czcionką, aktualizowany co 2s
- **Czas trwania**: Format MM:SS, liczony od startu
- **Status**: "Trwa symulacja..." z animowanym spinnerem lub "Zakończono" z ikoną
- **Progress indicator**: Opcjonalnie progress bar jeśli znamy szacowany czas
- **Komunikat**: "Symulacja może potrwać do 5 minut. Możesz zamknąć przeglądarkę - symulacja kontynuuje w tle."
- **Po zakończeniu**: 
  - Success: "Trafiono 5+2 po [X] próbach!" + szczegóły wyniku
  - Timeout: "Osiągnięto limit [prób/czasu]" + szczegóły
  - Przyciski: "Powrót do listy", "Uruchom nową symulację"

#### Historia symulacji:
- Tabela wszystkich symulacji użytkownika:
  - Nazwa strategii (link do szczegółów strategii)
  - Target draw (data)
  - Liczba prób
  - Czas trwania
  - Status z kolorowym wskaźnikiem (zielony=success, żółty=timeout, czerwony=error)
  - Przycisk "Zobacz szczegóły"
- Filtry: po strategii, po statusie
- Sortowanie: najnowsze na górze

**Kluczowe komponenty widoku**:
- **Start simulation form**: Formularz DaisyUI z select i input
- **Live tracking card**: Duża karta z licznikiem i statusem, aria-live="polite"
- **Simulation result card**: Karta z wynikiem i akcjami po zakończeniu
- **Simulations history table**: Tabela z filtrowaniem i sortowaniem
- **Simulation details modal**: Modal z pełnym result JSON sformatowanym czytelnie
- **Pagination**: 20 symulacji na stronę

**UX, dostępność i względy bezpieczeństwa**:
- Live tracking z aria-live="polite" dla screen readers
- Licznik prób w dużym kontraście i rozmiarze
- Loading state podczas uruchamiania symulacji
- Timeout handling z jasnym komunikatem
- Auto-refresh po reconnection (LiveView obsługuje automatycznie)
- Możliwość zamknięcia przeglądarki bez przerwania symulacji
- Status wskaźniki z ikonami + kolor dla accessibility
- Dane symulacji scope'owane po user_id
- Responsywny: tracking card na pełną szerekość mobile, tabela → karty na mobile

---

### 2.5 Sekcja Rankingu (Sekcja :ranking)

**Ścieżka**: `/` z `@active_section = :ranking`

**Główny cel**: Porównanie strategii według skuteczności

**Kluczowe informacje do wyświetlenia**:
- Lista strategii posortowana według mediany prób (rosnąco - niższa = lepsza):
  - **Pozycja w rankingu**: #1, #2, #3...
  - **Nazwa strategii** (link do szczegółów)
  - **Typ**: badge (manual/ai_generated)
  - **Mediana liczby prób**: główna metryka, wyróżniona wizualnie
  - **Liczba symulacji**: context dla mediany
  - **Performance score**: dodatkowe dane
- **Top 3 strategie**: Wyróżnione wizualnie (złoty/srebrny/brązowy badge lub kolor tła)
- **Strategie bez symulacji**: Na końcu listy z oznaczeniem "Brak danych" i linkiem do uruchomienia symulacji

**Kluczowe komponenty widoku**:
- **Ranking table/cards**: Lista z wyraźną hierarchią wizualną
- **Top 3 badges**: Specjalne ikony/kolory dla podium
- **Strategy details modal**: Modal z szczegółami strategii (link z nazwy)
- **Empty state**: Jeśli brak strategii z symulacjami: komunikat + link do tworzenia strategii
- **Expandable list**: Top 10 domyślnie, przycisk "Pokaż więcej" dla reszty

**UX, dostępność i względy bezpieczeństwa**:
- Wyraźna visual hierarchy dla top 3
- Tooltips na hover wyjaśniające metryki (opcjonalnie)
- Kolor + ikona dla top 3 (nie tylko kolor - accessibility)
- Link do uruchomienia symulacji dla strategii bez danych
- Performance score aktualizowany automatycznie przez PubSub po nowych symulacjach
- Dane scope'owane po user_id
- Responsywny: tabela → karty z wyraźnym rankingiem na mobile

---

### 2.6 Sekcja Generatora (Sekcja :generator)

**Ścieżka**: `/` z `@active_section = :generator`

**Główny cel**: Generowanie propozycji liczb na najbliższe losowanie

**Kluczowe informacje do wyświetlenia**:

#### Identyfikacja top strategii:
- **Top 3 strategie użytkownika**: Nazwy i mediany prób
- **Jeśli brak symulacji**: Komunikat "Najpierw uruchom symulacje aby znaleźć najlepsze strategie" + linki do:
  - "Wygeneruj nową strategię przez AI"
  - "Uruchom symulację"

#### Konfiguracja generowania:
- **Wybór strategii**: Dropdown z top 3 lub wszystkimi strategiami
- **Liczba kuponów**: Slider lub input (1-10)
- **Przycisk**: "Generuj propozycje"

#### Wyświetlenie kuponów:
- **N kuponów** (każdy w osobnej karcie DaisyUI):
  - Numeracja: "Kupon 1", "Kupon 2", etc.
  - **Główne liczby**: 5 okrągłych elementów (kule) z numerami, kolor niebieski
  - **Euro liczby**: 2 okrągłe elementy (kule) z numerami, kolor żółty
  - Kule ułożone w rzędach (flexbox desktop, wrap na mobile)
- **Przycisk**: "Wylosuj inne" (regeneracja wszystkich kuponów)

**Kluczowe komponenty widoku**:
- **Top strategies display**: Karty z top 3 strategiami
- **Generator form**: Formularz z select, slider, button
- **Coupons grid**: Grid kart z kuponami
- **Coupon card**: Karta DaisyUI z kulami (balls)
- **Ball component**: Okrągły element (avatar DaisyUI lub custom CSS) z numerem wewnątrz
- **Regenerate button**: Secondary button pod wszystkimi kuponami
- **Empty state**: Komunikat + akcje jeśli brak strategii z symulacjami

**UX, dostępność i względy bezpieczeństwa**:
- Loading state podczas generowania (spinner w przycisku)
- Walidacja: każdy kupon unikalny
- Różne kolory dla głównych vs euro liczb
- Numeracja kuponów dla łatwej identyfikacji
- Przycisk "Wylosuj inne" zawsze widoczny, nie ukryty
- Komunikat jeśli brak top strategii z pomocnymi linkami
- Aria-labels dla kul z numerami
- Dane kuponów ephemeral (nie zapisywane w bazie w MVP1)
- Responsywny: kule w rzędach desktop, wrap do 2 rzędów mobile jeśli potrzeba

---

### 2.7 Nawigacja (Navbar/Drawer)

**Ścieżka**: Obecna na wszystkich widokach po zalogowaniu

**Główny cel**: Umożliwienie łatwej nawigacji między sekcjami

**Kluczowe informacje do wyświetlenia**:
- Logo/nazwa aplikacji: "Numbers Evolution"
- Linki do sekcji:
  - Dashboard
  - Strategie
  - Symulacje
  - Ranking
  - Generator
- User menu: Email użytkownika + dropdown:
  - Zmień hasło
  - Wyloguj

**Kluczowe komponenty widoku**:
- **Desktop navbar** (>768px): Navbar DaisyUI poziomy, zawsze widoczny na górze
- **Mobile drawer** (≤768px): Hamburger menu (DaisyUI drawer) otwierający boczne menu
- **Active section indicator**: Wizualne wyróżnienie aktywnej sekcji (btn-active w DaisyUI)
- **Theme switcher**: Toggle light/dark (opcjonalnie w MVP1)

**UX, dostępność i względy bezpieczeństwa**:
- Nawigacja przez phx-click (bez zmiany URL)
- Aktywna sekcja wyraźnie wyróżniona
- Mobile drawer zamyka się po kliknięciu linku
- Semantyczny tag `<nav>`
- Keyboard navigation support (tab order)
- Focus states widoczne (Tailwind focus:ring)
- Wylogowanie czyści assigns i przekierowuje na landing

---

### 2.8 Modale (wykorzystywane w wielu widokach)

#### Modal szczegółów strategii:
- Nazwa strategii (edytowalna inline lub przez formularz)
- Typ (badge)
- Rules (JSON sformatowany czytelnie, z labeling)
- Performance score i mediana prób
- Reasoning (dla AI strategies)
- Oryginalny prompt (dla AI strategies)
- **Historia symulacji**: Mini tabela symulacji dla tej strategii
- **Akcje**: Edytuj, Usuń, Uruchom symulację

#### Modal szczegółów symulacji:
- Nazwa strategii (link do strategii)
- Target draw (data + wylosowane liczby)
- Liczba prób
- Czas trwania
- Status
- **Result JSON**: Sformatowany czytelnie:
  - matched_main
  - matched_euro
  - final_draw
- Przycisk zamknięcia

#### Modal potwierdzenia usunięcia:
- Komunikat: "Czy na pewno usunąć strategię [nazwa]?"
- Przyciski: "Anuluj", "Usuń" (danger button)

## 3. Mapa podróży użytkownika

### 3.1 Główne przepływy użytkownika

#### Przepływ 1: Nowy użytkownik - Rejestracja i pierwsze kroki

1. **Landing Page** → Użytkownik widzi opis aplikacji i funkcjonalności
2. **Klik "Zarejestruj się"** → Formularz rejestracji (Phoenix auth)
3. **Po rejestracji** → Automatyczne logowanie i przekierowanie na :dashboard
4. **Dashboard (puste)** → Statystyki pokazują 0/0/brak, quick actions widoczne
5. **Klik "Utwórz nową strategię"** → Przełączenie na :strategies, formularz otwarty
6. **Wybór: Tab "AI" lub "Manualna"**:
   - **AI**: Wpisanie promptu → Generowanie → Zapisanie strategii
   - **Manualna**: Wypełnienie parametrów → Zapisanie strategii
7. **Po zapisaniu** → Flash message success, powrót do listy strategii
8. **Klik "Uruchom symulację"** → Przełączenie na :simulations
9. **Wybór strategii i target draw** → Uruchomienie symulacji
10. **Live tracking** → Obserwowanie licznika prób w real-time
11. **Po zakończeniu** → Wynik success/timeout, możliwość powrotu lub uruchomienia nowej
12. **Klik "Powrót do listy"** → Historia symulacji, nowa symulacja na liście
13. **Przejście do :ranking** → Strategia pojawia się w rankingu z performance score

#### Przepływ 2: Analityk Tomek - Testowanie i optymalizacja strategii

1. **Logowanie** → Dashboard z istniejącymi strategiami i symulacjami
2. **Przejście do :strategies** → Przegląd listy strategii
3. **Klik "Zobacz szczegóły"** na strategii → Modal z pełnymi informacjami i historią symulacji
4. **Analiza performance** → Sprawdzenie mediany prób i reasoning
5. **Decyzja o utworzeniu miksu** → Zaznaczenie 2-3 strategii checkboxami
6. **Klik "Utwórz mix"** → Modal z generowaniem przez AI
7. **Wynik miksu** → Nowa strategia zapisana, pojawia się na liście
8. **Uruchomienie symulacji na miksie** → Przejście do :simulations
9. **Porównanie w :ranking** → Sprawdzenie czy miks jest lepszy od składowych
10. **Iteracja** → Ewentualne kolejne tweaki i testy

#### Przepływ 3: Gracz Marek - Szybkie generowanie propozycji

1. **Logowanie** → Dashboard
2. **Klik "Generuj propozycje"** → Przejście do :generator
3. **Sprawdzenie top 3 strategii** → Wybór najlepszej (najniższa mediana)
4. **Ustawienie liczby kuponów** → Slider na 5 kuponów
5. **Klik "Generuj propozycje"** → Loading state, generowanie
6. **Wyświetlenie kuponów** → 5 kart z wizualnymi kulami
7. **Przepisanie liczb** lub **Klik "Wylosuj inne"** → Regeneracja nowych zestawów
8. **Zapisanie liczb** (poza systemem) → Użycie do zakupu kuponu

#### Przepływ 4: Obsługa błędów AI

1. **Formularz AI w :strategies** → Wpisanie promptu
2. **Klik "Generuj strategię AI"** → Loading state
3. **Błąd API (503 Service Unavailable)** → Alert-error z komunikatem:
   - "Usługa AI jest tymczasowo niedostępna. Spróbuj ponownie za chwilę lub utwórz strategię manualnie."
   - Przycisk "Spróbuj ponownie"
   - Link "Utwórz strategię manualnie" → Przełączenie na tab "Manualna"
4. **Klik "Spróbuj ponownie"** → Ponowne wywołanie z tym samym promptem
5. **Sukces** → Wygenerowana strategia, możliwość zapisu

#### Przepływ 5: Live tracking z utratą połączenia

1. **Uruchomienie symulacji** → Live tracking aktywny, licznik aktualizuje się co 2s
2. **Utrata połączenia internet** → LiveView wykrywa, komunikat "Utracono połączenie. Próba ponownego połączenia..."
3. **Symulacja kontynuuje na serwerze** → Backend działa niezależnie
4. **Odzyskanie połączenia** → LiveView reconnect, synchronizacja stanu
5. **Użytkownik widzi aktualny stan** → Licznik pokazuje aktualną liczbę prób lub wynik jeśli zakończono
6. **Kontynuacja bez przerwania UX** → Seamless experience

### 3.2 Kluczowe punkty decyzyjne

- **Dashboard vs konkretna sekcja**: Quick actions pozwalają na szybkie przejście
- **AI vs Manualna strategia**: Taby w formularzu, łatwe przełączanie
- **Uruchomienie symulacji vs analiza wyników**: Dwa osobne sub-widoki w :simulations
- **Miksowanie strategii vs tworzenie nowej**: Mix w kontekście listy strategii, jasne checkboxy
- **Generowanie kuponów z top strategią vs wybór własnej**: Default to top 1, opcja zmiany w dropdown

### 3.3 Stany brzegowe i error handling

#### Brak danych:
- **Dashboard (nowy user)**: Quick actions widoczne, zachęta do utworzenia pierwszej strategii
- **:strategies (pusta lista)**: "Nie masz jeszcze strategii" + przycisk "Utwórz pierwszą strategię"
- **:simulations (pusta historia)**: "Nie uruchomiłeś jeszcze symulacji" + formularz uruchomienia
- **:ranking (brak strategii z symulacjami)**: "Uruchom symulacje aby zobaczyć ranking" + link
- **:generator (brak symulacji)**: Komunikat + linki do utworzenia strategii i uruchomienia symulacji

#### Błędy walidacji:
- **Formularz strategii**: Inline errors przy polach, suma wag/ratio pokazana na bieżąco
- **Formularz symulacji**: Walidacja limitów (min/max)
- **Mix konfliktujących strategii**: Alert w modalu z opisem konfliktów

#### Błędy API:
- **429 Rate Limit**: "Przekroczono limit żądań. Możesz wygenerować 5 strategii przez AI dziennie. Spróbuj ponownie jutro."
- **503 AI Timeout**: "Usługa AI jest tymczasowo niedostępna..." + retry button
- **401 Unauthorized**: Alert na górze + przekierowanie na login
- **500 Server Error**: "Wystąpił błąd serwera. Spróbuj ponownie później."

## 4. Układ i struktura nawigacji

### 4.1 Architektura nawigacji

```
/ (PageLive - główny LiveView)
├── :landing (niezalogowani)
│   └── Formularz Login/Register (Phoenix auth)
│
└── Zalogowani użytkownicy:
    ├── Navbar/Drawer (zawsze widoczny)
    │   ├── Dashboard
    │   ├── Strategie
    │   ├── Symulacje
    │   ├── Ranking
    │   ├── Generator
    │   └── User menu (Wyloguj)
    │
    ├── :dashboard
    │   ├── Stats cards
    │   ├── Quick actions → nawigacja do innych sekcji
    │   └── Recent simulations → modal szczegółów
    │
    ├── :strategies
    │   ├── Lista strategii
    │   │   ├── Zobacz szczegóły → modal
    │   │   ├── Edytuj → formularz
    │   │   ├── Usuń → modal potwierdzenia
    │   │   └── Checkboxy → Utwórz mix → modal
    │   ├── Formularz tworzenia (modal/section)
    │   │   ├── Tab: Manualna
    │   │   └── Tab: AI
    │   └── Paginacja (20/strona)
    │
    ├── :simulations
    │   ├── Formularz uruchomienia
    │   ├── :simulation_tracking (podsekcja)
    │   │   ├── Live counter
    │   │   └── Result → akcje
    │   ├── Historia symulacji
    │   │   └── Zobacz szczegóły → modal
    │   └── Paginacja (20/strona)
    │
    ├── :ranking
    │   ├── Lista strategii (top 10 domyślnie)
    │   ├── Nazwa strategii → modal szczegółów
    │   └── "Pokaż więcej" → rozwinięcie listy
    │
    └── :generator
        ├── Top 3 strategie
        ├── Formularz konfiguracji
        ├── Wyświetlenie kuponów (grid)
        └── Regeneracja
```

### 4.2 Wzorce nawigacji

#### Nawigacja między sekcjami:
- **Phx-click events**: Zmiana `@active_section` bez URL change
- **Przykład**: `<button phx-click="navigate" phx-value-section="strategies">Strategie</button>`
- **Handler**: `handle_event("navigate", %{"section" => section}, socket)` → `assign(socket, :active_section, String.to_atom(section))`

#### Nawigacja w obrębie sekcji:
- **Modale**: Zmiana assign `@show_modal` i `@modal_data`
- **Podsekcje**: Zmiana assign np. `@simulation_state` (:form / :tracking / :history)
- **Taby**: Zmiana assign `@active_tab` w formularzu strategii

#### Deep linking (opcjonalnie post-MVP):
- W MVP1 wszystkie sekcje na `/` bez URL params
- Post-MVP można dodać URL params dla bookmarkowania: `/?section=strategies&id=uuid`

### 4.3 Breadcrumbs i kontekst

Brak tradycyjnych breadcrumbs w SPA, zamiast tego:
- **Aktywna sekcja wyróżniona w navbar** (btn-active)
- **Nagłówki sekcji**: `<h1>Dashboard</h1>`, `<h1>Moje Strategie</h1>`, etc.
- **Back buttons**: W podsekcjach (np. live tracking → "Powrót do listy")
- **Modal titles**: Jasno komunikują kontekst (np. "Szczegóły strategii: [nazwa]")

### 4.4 Responsywna nawigacja

#### Desktop (>768px):
- **Navbar poziomy**: Logo + linki do sekcji + user menu (prawą stronę)
- **Zawsze widoczny**: Fixed na górze
- **Hover states**: Podkreślenie/highlight przy najechaniu
- **Active state**: Wyraźniejszy kolor/tło dla aktywnej sekcji

#### Mobile (≤768px):
- **Hamburger icon**: Lewy górny róg
- **Drawer (sidebar)**: Otwiera się z lewej strony (DaisyUI drawer)
- **Overlay**: Przyciemnienie tła gdy drawer otwarty
- **Zawartość drawer**:
  - Logo na górze
  - Lista sekcji (pionowo)
  - User menu na dole
- **Zamykanie**: Klik na overlay lub na link sekcji

## 5. Kluczowe komponenty

### 5.1 Komponenty wspólne (w core_components.ex)

#### Button variants:
- **Primary**: Główne akcje (DaisyUI `btn btn-primary`)
- **Secondary**: Drugorzędne akcje (DaisyUI `btn btn-secondary`)
- **Danger**: Usuwanie (DaisyUI `btn btn-error`)
- **Ghost**: Subtle actions (DaisyUI `btn btn-ghost`)
- **Loading state**: Spinner + disabled gdy `phx-click-loading`

#### Card:
- **Base card**: DaisyUI `card bg-base-100 shadow-xl`
- **Stats card**: Z ikoną, tytułem, wartością
- **Coupon card**: Z kulami numerów
- **Strategy card**: Z nazwą, typem, metrykami

#### Modal:
- **DaisyUI modal**: `<dialog class="modal">`
- **Backdrop**: Klik zamyka modal
- **Close button**: X w prawym górnym rogu
- **Footer**: Z akcjami (Cancel, Confirm)

#### Form controls:
- **Input**: DaisyUI `input input-bordered`
- **Select**: DaisyUI `select select-bordered`
- **Textarea**: DaisyUI `textarea textarea-bordered`
- **Checkbox**: DaisyUI `checkbox`
- **Toggle**: DaisyUI `toggle` (dla theme switcher)
- **Range slider**: DaisyUI `range`
- **Label**: Zawsze powiązany z input przez `for` attribute

#### Alert:
- **Info**: DaisyUI `alert alert-info`
- **Success**: DaisyUI `alert alert-success`
- **Warning**: DaisyUI `alert alert-warning`
- **Error**: DaisyUI `alert alert-error`
- **Dismissible**: Z przyciskiem X

#### Toast (Flash messages):
- **DaisyUI toast**: Prawy górny róg
- **Auto-dismiss**: Po 5 sekundach
- **Typy**: Odpowiadające alertom (info/success/warning/error)

#### Loading:
- **Spinner**: DaisyUI `loading loading-spinner`
- **Progress**: DaisyUI `progress` (dla live tracking)
- **Skeleton**: DaisyUI `skeleton` (dla placeholders)

#### Table:
- **DaisyUI table**: `table table-zebra`
- **Sortable headers**: Z ikonami strzałek
- **Row actions**: Przyciski w ostatniej kolumnie
- **Empty state**: Row z colspan i komunikatem

#### Pagination:
- **DaisyUI join**: Przyciski numerów stron
- **Previous/Next**: Z ikonami strzałek
- **Current page**: Wyróżniony (btn-active)

### 5.2 Komponenty specyficzne dla domeny

#### Ball (number ball):
- **Okrągły element**: `border-radius: 50%`
- **Rozmiar**: 50x50px desktop, 40x40px mobile
- **Numer**: Wycentrowany, duża czcionka (20px-24px)
- **Kolory**:
  - Główne liczby: niebieski (#3B82F6)
  - Euro liczby: żółty (#F59E0B)
- **Accessibility**: Aria-label z tekstem "Główna liczba [X]" lub "Euro liczba [X]"

#### Strategy badge:
- **Typ**: Manual (niebieski badge) / AI Generated (zielony badge)
- **Rozmiar**: Small badge, obok nazwy strategii
- **Ikony**: Opcjonalnie ikona ręki dla manual, ikona AI dla generated

#### Status indicator:
- **Running**: Żółty spinner + "Trwa..."
- **Success**: Zielona ikona check + "Sukces"
- **Timeout**: Pomarańczowa ikona clock + "Timeout"
- **Error**: Czerwona ikona X + "Błąd"

#### Performance chart (opcjonalnie post-MVP):
- Wykres słupkowy mediany prób dla strategii
- Sparkline trendu dla historii symulacji

### 5.3 Layout components

#### Page container:
- **Max width**: 1280px na desktop
- **Padding**: px-4 sm:px-6 lg:px-8 (Tailwind)
- **Margin**: mx-auto (wycentrowanie)

#### Section:
- **Spacing**: py-8 sm:py-12 (Tailwind)
- **Semantic tag**: `<section>` z aria-label

#### Grid:
- **Strategies/Simulations**: Grid 1-3 kolumny responsywnie
- **Stats cards**: Grid 1-4 kolumny responsywnie
- **Coupons**: Grid 1-2 kolumny responsywnie

### 5.4 Utility components

#### Empty state:
- **Ikona**: Duża ilustracyjna ikona (Heroicons)
- **Heading**: "Nie masz jeszcze [X]"
- **Description**: Wyjaśnienie co użytkownik może zrobić
- **CTA**: Primary button z akcją

#### Error boundary:
- **Fallback UI**: Gdy komponent się wysypie
- **Komunikat**: "Coś poszło nie tak" + przycisk "Odśwież"

#### Loading overlay:
- **Full screen lub sekcja**: Semi-transparent backdrop
- **Spinner**: Wycentrowany
- **Komunikat**: Opcjonalnie tekst "Ładowanie..."

---

## 6. Mapowanie wymagań funkcjonalnych na elementy UI

### F7: Autoryzacja użytkowników

| Wymaganie | Element UI | Lokalizacja |
|-----------|-----------|-------------|
| F7.1 Rejestracja | Formularz rejestracji | Landing page → klik "Zarejestruj się" |
| F7.2 Logowanie | Formularz logowania | Landing page → klik "Zaloguj" |
| F7.2 Wylogowanie | Link "Wyloguj" | Navbar → User menu |
| F7.3 Zmiana hasła | Formularz zmiany hasła | User menu → "Zmień hasło" |
| F7.4 Izolacja danych | Scope queries po user_id | Wszystkie sekcje (backend) |

### F1: Zarządzanie strategiami

| Wymaganie | Element UI | Lokalizacja |
|-----------|-----------|-------------|
| F1.1 CRUD strategii | Lista + formularze | :strategies sekcja |
| F1.2 Tworzenie manualnie | Tab "Manualna" | Formularz strategii |
| F1.3 Generowanie przez AI | Tab "AI" | Formularz strategii |
| F1.4 Przechowywanie | Backend (baza danych) | - |
| F1.5 Mieszanie strategii | Checkboxy + modal | Lista strategii |

### F6: Dane historyczne Eurojackpot

| Wymaganie | Element UI | Lokalizacja |
|-----------|-----------|-------------|
| F6.1 Seed losowań | Backend (seeding) | - |
| F6.2 Struktura uniwersalna | Backend (tabela draws) | - |
| F6.3 Aktualizacja danych | Backend (manual seeding) | - |
| Wybór target draw | Dropdown w formularzu | :simulations → formularz uruchomienia |

### F2: Silnik symulacji

| Wymaganie | Element UI | Lokalizacja |
|-----------|-----------|-------------|
| F2.1 Uruchamianie symulacji | Formularz + przycisk | :simulations → formularz |
| F2.2 Proces symulacji | Backend (Task.async) | - |
| F2.3 Limity bezpieczeństwa | Inputy w formularzu | :simulations → opcjonalne limity |
| F2.4 Wykonanie w tle | Backend | - |
| F2.5 Zapis wyniku | Backend (tabela simulations) | - |

### F3: Live tracking w LiveView

| Wymaganie | Element UI | Lokalizacja |
|-----------|-----------|-------------|
| F3.1 Real-time aktualizacja | Licznik prób | :simulation_tracking podsekcja |
| F3.2 Wyświetlane informacje | Licznik, czas, status | :simulation_tracking karta |
| F3.3 Ograniczenia MVP1 | Brak przycisku Stop, ETA | - |

### F4: Ranking i analiza wyników

| Wymaganie | Element UI | Lokalizacja |
|-----------|-----------|-------------|
| F4.1 Obliczanie performance_score | Backend (mediana) | - |
| F4.2 Ranking strategii | Lista posortowana | :ranking sekcja |
| F4.3 Wyświetlane dane | Tabela/karty | :ranking lista |
| F4.4 Historia symulacji | Tabela z filtrowaniem | :simulations → historia |
| F4.5 Ranking mixów | Część ogólnego rankingu | :ranking (mixy traktowane jako strategie) |

### F5: Generator propozycji na losowanie

| Wymaganie | Element UI | Lokalizacja |
|-----------|-----------|-------------|
| F5.1 Identyfikacja top strategii | Display top 3 | :generator → top strategii |
| F5.2 Konfiguracja generowania | Formularz (strategia, liczba) | :generator → formularz |
| F5.3 Generowanie kuponów | Backend | - |
| F5.4 UI generatora | Kule + przycisk "Wylosuj inne" | :generator → kuponygrid |

### F8: Dashboard LiveView

| Wymaganie | Element UI | Lokalizacja |
|-----------|-----------|-------------|
| F8.1 Architektura SPA | PageLive z @active_section | `/` (cała aplikacja) |
| F8.2 Landing page | Sekcja :landing | `/` dla niezalogowanych |
| F8.3 Dashboard | Sekcja :dashboard | `/` domyślna po logowaniu |
| F8.4 Sekcja strategii | Sekcja :strategies | `/` z nawigacją |
| F8.5 Sekcja symulacji | Sekcja :simulations | `/` z nawigacją |
| F8.6 Sekcja rankingu | Sekcja :ranking | `/` z nawigacją |
| F8.7 Sekcja generatora | Sekcja :generator | `/` z nawigacją |

---

## 7. Historyjki użytkownika - mapowanie na UI

### US-001 do US-004: Autoryzacja
- **UI**: Formularze Phoenix auth (login, register, password change)
- **Lokalizacja**: Landing page, User menu

### US-005: Przeglądanie listy strategii
- **UI**: Tabela/karty strategii z sortowaniem wg performance_score
- **Lokalizacja**: :strategies sekcja

### US-006: Tworzenie strategii manualnie
- **UI**: Formularz w tab "Manualna" z walidacją inline
- **Lokalizacja**: :strategies → formularz tworzenia

### US-007, US-008: Generowanie strategii przez AI
- **UI**: Textarea w tab "AI", loading state, obsługa błędów
- **Lokalizacja**: :strategies → formularz tworzenia

### US-009, US-010: Edycja i usuwanie strategii
- **UI**: Przyciski akcji, formularz edycji, modal potwierdzenia
- **Lokalizacja**: :strategies → lista strategii

### US-011: Wyświetlanie szczegółów strategii
- **UI**: Modal z pełnymi informacjami i historią symulacji
- **Lokalizacja**: :strategies → modal szczegółów

### US-012: Tworzenie miksu strategii
- **UI**: Checkboxy na liście, przycisk "Utwórz mix", modal
- **Lokalizacja**: :strategies → lista strategii

### US-013, US-014: Uruchamianie i live tracking symulacji
- **UI**: Formularz uruchomienia + karta live tracking
- **Lokalizacja**: :simulations → formularz i :simulation_tracking

### US-015: Przeglądanie historii symulacji
- **UI**: Tabela z filtrowaniem i sortowaniem
- **Lokalizacja**: :simulations → historia

### US-016, US-017: Ranking strategii i mixów
- **UI**: Lista posortowana z top 3 wyróżnionymi
- **Lokalizacja**: :ranking sekcja

### US-019, US-020, US-021: Generator propozycji
- **UI**: Top 3 display, formularz, kule z numerami, przycisk regeneracji
- **Lokalizacja**: :generator sekcja

### US-022: Przeglądanie dashboard
- **UI**: Stats cards, quick actions, recent simulations
- **Lokalizacja**: :dashboard sekcja

### US-023: Nawigacja między sekcjami
- **UI**: Navbar desktop / Drawer mobile
- **Lokalizacja**: Zawsze widoczny dla zalogowanych

### US-024: Landing page
- **UI**: Hero, features, CTA, disclaimer
- **Lokalizacja**: :landing sekcja

### US-025: Walidacja strategii
- **UI**: Inline errors w formularzu, suma wag/ratio na bieżąco
- **Lokalizacja**: :strategies → formularz

### US-026: Długo działające symulacje
- **UI**: Komunikat o możliwości zamknięcia przeglądarki
- **Lokalizacja**: :simulation_tracking

### US-033: Responsive design
- **UI**: Tailwind breakpoints, hamburger menu, adaptacyjne gridy
- **Lokalizacja**: Wszystkie sekcje

---

## 8. Punkty bólu użytkownika i rozwiązania UI

### Punkt bólu 1: "Nie wiem od czego zacząć"
**Rozwiązanie UI**:
- Dashboard z wyraźnymi quick actions
- Empty states z pomocnymi komunikatami i akcjami
- Landing page jasno komunikuje wartość

### Punkt bólu 2: "Tworzenie strategii jest skomplikowane"
**Rozwiązanie UI**:
- Dwa podejścia: Manualne (dla analityków) + AI (dla wygody)
- Tab "AI" jako prostsza alternatywa
- Przykłady promptów jako wskazówki
- Walidacja w real-time pokazuje błędy od razu

### Punkt bólu 3: "Nie wiem czy moja strategia działa"
**Rozwiązanie UI**:
- Live tracking symulacji w real-time
- Ranking z wyraźną hierarchią
- Performance score jako główna metryka
- Historia symulacji z szczegółami

### Punkt bólu 4: "Symulacje trwają długo"
**Rozwiązanie UI**:
- Jasny komunikat o możliwości zamknięcia przeglądarki
- Live tracking pokazuje postęp
- Możliwość kontynuacji po reconnection
- Timeouty z sensownymi defaultami

### Punkt bólu 5: "Chcę szybko wygenerować liczby"
**Rozwiązanie UI**:
- Dedykowana sekcja :generator
- Automatyczna identyfikacja top 3 strategii
- Prosty formularz (2 pola)
- Wizualizacja jako kule (łatwo przepisać)
- Przycisk "Wylosuj inne" dla wygody

### Punkt bólu 6: "Gubię się w danych"
**Rozwiązanie UI**:
- Filtry i sortowanie w tabelach
- Paginacja (20 elementów/strona)
- Modale dla szczegółów (kontekst zachowany)
- Visual hierarchy (top 3 wyróżnione)

### Punkt bólu 7: "Nie rozumiem co poszło nie tak"
**Rozwiązanie UI**:
- Przyjazne komunikaty błędów
- Konkretne akcje (retry, fallback do manual)
- Inline errors przy polach formularza
- Flash messages dla wszystkich akcji

### Punkt bólu 8: "Interfejs nie działa na telefonie"
**Rozwiązanie UI**:
- Responsywny design od początku
- Hamburger menu na mobile
- Formularze w jednej kolumnie
- Kule wrap na mobile
- Touch-friendly rozmiary przycisków

---

## 9. Accessibility i UX - szczegóły implementacyjne

### 9.1 Keyboard navigation
- Wszystkie interactive elements dostępne przez Tab
- Skip links dla szybkiej nawigacji
- Focus states widoczne (Tailwind focus:ring)
- Modal traps focus (nie można tabem wyjść)
- ESC zamyka modale

### 9.2 Screen readers
- Semantyczne tagi HTML (`<nav>`, `<main>`, `<section>`, `<article>`)
- Aria-labels dla ikonowych przycisków
- Aria-live="polite" dla live tracking
- Aria-describedby dla error messages
- Alt text dla ikon (przez Heroicons props)

### 9.3 Color contrast
- DaisyUI motywy zapewniają WCAG AA
- Nie tylko kolor dla statusów (ikona + kolor + tekst)
- Top 3 w rankingu: badge/ikona + kolor

### 9.4 Loading states
- Zawsze jasny komunikat co się dzieje
- Blokowanie interakcji podczas loading
- Timeout handling z opcją retry
- Skeleton screens dla list podczas ładowania

### 9.5 Error prevention
- Walidacja w real-time
- Confirmation modals dla destrukcyjnych akcji
- Disable przycisków podczas processing
- Jasne labeling (np. "Usuń strategię" zamiast tylko "Usuń")

---

## 10. Performance considerations

### 10.1 Optimization strategies
- LiveView assigns jako cache podczas sesji
- PubSub zamiast polling dla real-time updates
- Paginacja po stronie serwera (20 items/strona)
- Lazy loading images (jeśli będą w przyszłości)
- Debouncing dla search/filter inputs (post-MVP)

### 10.2 Bundle size
- DaisyUI: Pure CSS, zero JS overhead
- Tailwind v4: Tylko używane klasy w bundle
- Heroicons: Tree-shakeable
- No external JS frameworks (LiveView jest wystarczający)

### 10.3 Perceived performance
- Optimistic UI updates gdzie możliwe
- Loading states natychmiast widoczne
- Skeleton screens dla list
- Subtle transitions (200-300ms) dla UX, nie za długie

---

**Koniec dokumentu architektury UI**

