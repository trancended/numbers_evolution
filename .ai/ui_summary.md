# Podsumowanie planowania architektury UI - Numbers Evolution MVP

<conversation_summary>

<decisions>

1. **Architektura Single Page Application**: Zaimplementować główny LiveView (`PageLive`) na `/` z systemem sekcji zarządzanym przez assign `@active_section`. Sekcje: `:landing`, `:dashboard`, `:strategies`, `:simulations`, `:ranking`, `:generator`. Nawigacja przez `phx-click` bez zmiany URL.

2. **Dashboard jako osobna sekcja**: Dashboard jest osobną sekcją wyświetlaną domyślnie po zalogowaniu, zawierającą statystyki użytkownika, quick actions i ostatnie symulacje.

3. **Widoki szczegółów jako modale**: Szczegóły strategii i symulacji wyświetlane w modalach DaisyUI, pozwalających na szybki podgląd bez opuszczania kontekstu listy.

4. **Przepływ AI strategy generation**: Tab "AI" w sekcji strategii z textarea (max 500 znaków), loading state, obsługa błędów z przyciskiem retry, brak automatycznego fallbacku.

5. **Live tracking symulacji**: Osobna podsekcja `:simulation_tracking` z dużym licznikiem prób, czasem trwania, statusem. Aktualizacje co 2 sekundy przez LiveView messaging.

6. **Mix strategii w sekcji strategii**: Checkboxy do zaznaczania 2-3 strategii, przycisk "Utwórz mix", modal z loading state podczas generowania przez AI.

7. **Responsywna nawigacja**: Desktop (>768px): navbar zawsze widoczny. Mobile (≤768px): hamburger menu (DaisyUI drawer).

8. **Wizualizacja kuponów**: Okrągłe elementy (kule) z numerami, różne kolory dla głównych vs euro liczb, responsywne układy.

9. **Podstawowe wymagania a11y**: Semantyczne HTML, właściwe nagłówki, aria-labels, focus states, WCAG AA compliance, aria-live dla live tracking.

10. **Loading states**: Różne poziomy dla szybkich (<1s), średnich (1-5s) i długich (>5s) operacji, z odpowiednimi komunikatami i timeout handling.

11. **Autoryzacja przez on_mount hook**: Sprawdzanie `assigns.current_user`, przekierowanie na landing dla niezalogowanych, automatyczne przełączenie na dashboard po zalogowaniu.

12. **Obsługa błędów API**: Inline validation errors, alerty dla autoryzacji, dedykowane komunikaty dla różnych typów błędów (429, 503, 400, 500).

13. **Komponenty DaisyUI + Tailwind CSS v4**: Wykorzystanie gotowych komponentów DaisyUI jako podstawy, Tailwind utilities dla custom styling, komponenty w `core_components.ex`.

14. **Flash messages jako toast**: Phoenix flash messages wyświetlane jako toast notifications w prawym górnym rogu, automatyczne znikanie po 5 sekundach.

15. **Zarządzanie stanem przez LiveView assigns**: Standardowe podejście LiveView z assigns dla każdej sekcji, ładowanie danych przez Context modules, PubSub dla real-time updates.

16. **Paginacja po stronie serwera**: Query parameters API (`page`, `per_page`), DaisyUI join z przyciskami, 20 elementów na stronę domyślnie.

17. **Cache'owanie danych**: Dane statyczne cache'owane w assigns, dynamiczne świeże przy przełączeniu sekcji, draws cache'owane 5-10 minut, performance score przez PubSub.

18. **Obsługa utraty połączenia**: LiveView automatycznie wykrywa i obsługuje reconnection, synchronizacja stanu po ponownym połączeniu.

</decisions>

<matched_recommendations>

1. **Hierarchia sekcji SPA**: Główny LiveView z `@active_section` assign, sekcje jako komponenty funkcjonalne, nawigacja przez `phx-click`.

2. **Dashboard jako domyślna sekcja**: Osobna sekcja z statystykami i quick actions, wyświetlana po zalogowaniu.

3. **Modale dla szczegółów**: DaisyUI modal dla strategii i symulacji, szybki podgląd bez opuszczania kontekstu.

4. **Przepływ AI z obsługą błędów**: Textarea z licznikiem, loading state, alert-error dla błędów, przycisk retry.

5. **Live tracking jako podsekcja**: Osobna podsekcja z dużym licznikiem, aktualizacje przez `handle_info`, automatyczne przełączenie po zakończeniu.

6. **Mix w sekcji strategii**: Checkboxy, aktywny przycisk przy 2-3 zaznaczonych, modal z loading podczas generowania.

7. **Responsywna nawigacja**: Navbar desktop, drawer mobile, aktywne sekcje wyróżnione wizualnie.

8. **Responsywne kule kuponów**: Okrągłe elementy, flexbox desktop, dwa rzędy mobile, różne kolory.

9. **Podstawowe a11y**: Semantyczne HTML, aria-labels, focus states, WCAG AA, aria-live dla live tracking.

10. **Loading states z komunikatami**: Różne poziomy loading, jasne komunikaty, timeout handling, blokowanie interakcji.

11. **Autoryzacja przez hook**: `on_mount` sprawdza `current_user`, przekierowanie na landing, automatyczne przełączenie po login.

12. **Różne typy błędów API**: Inline validation, alerty autoryzacji, dedykowane komunikaty dla 429/503/400/500.

13. **DaisyUI + Tailwind v4**: Gotowe komponenty DaisyUI, Tailwind utilities, komponenty w `core_components.ex`, motywy light/dark.

14. **Toast flash messages**: Phoenix flash jako toast, prawy górny róg, auto-dismiss 5s, typy info/success/error/warning.

15. **Assigns dla stanu**: LiveView assigns dla każdej sekcji, Context modules dla danych, PubSub dla real-time.

16. **Paginacja serwerowa**: Query params API, DaisyUI join, 20 elementów domyślnie, top 10 dla rankingu.

17. **Strategia cache'owania**: Statyczne w assigns, dynamiczne świeże przy przełączeniu, draws 5-10 min, performance przez PubSub.

18. **Auto-reconnection**: LiveView automatycznie wykrywa i obsługuje, synchronizacja przez `after_join`.

19. **Różne loading states**: Subtle dla szybkich, overlay dla średnich, progress dla długich, timeout handling.

20. **Komunikaty dla wolnych połączeń**: Jasne komunikaty czasu trwania, informacja o możliwości zamknięcia przeglądarki dla długich operacji.

</matched_recommendations>

<ui_architecture_planning_summary>

## Główne wymagania dotyczące architektury UI

### Architektura Single Page Application

Aplikacja Numbers Evolution wykorzystuje Phoenix LiveView do stworzenia Single Page Application na głównej ścieżce `/`. Główny LiveView (`PageLive`) zarządza widocznością sekcji przez assign `@active_section`, który przyjmuje wartości: `:landing` (dla niezalogowanych), `:dashboard`, `:strategies`, `:simulations`, `:ranking`, `:generator`. Sekcje są renderowane jako komponenty funkcjonalne Phoenix (nie LiveComponents), co zapewnia prostotę i wydajność.

Nawigacja działa przez `phx-click` events, które zmieniają `@active_section` bez modyfikacji URL, zapewniając płynne przejścia bez przeładowania strony. To podejście jest zgodne z wymaganiami PRD (F8.1) i wykorzystuje mocne strony LiveView.

### Stack technologiczny UI

**Tailwind CSS v4**: Nowa składnia CSS-first z `@import "tailwindcss" source(none)`, automatyczne wykrywanie klas przez `@source`, konfiguracja przez `@theme` bezpośrednio w CSS. Custom variants dla LiveView loading states (`phx-click-loading`, `phx-submit-loading`).

**DaisyUI**: Gotowe komponenty UI jako klasy Tailwind (`btn`, `card`, `modal`, `alert`, `form-control`, `input`, `select`, `table`, `drawer`, `loading`). Dwa motywy: light (Phoenix-inspired) i dark (Elixir-inspired) z przełączaniem przez `data-theme` attribute.

**Heroicons**: Ikony przez `<.icon>` component z klasami CSS (`hero-x-mark`, `hero-check`, etc.).

## Kluczowe widoki, ekrany i przepływy użytkownika

### 1. Landing Page (`:landing`)

Widoczna tylko dla niezalogowanych użytkowników. Zawiera:
- Opis aplikacji (nazwa, tagline, główne funkcjonalności)
- Disclaimer prawny
- Call-to-action: przyciski "Zarejestruj się" i "Zaloguj"

### 2. Dashboard (`:dashboard`)

Domyślna sekcja po zalogowaniu. Wyświetla:
- **Statystyki użytkownika**: Liczba strategii, liczba symulacji, najlepsza strategia (nazwa + mediana prób), ostatnia aktywność
- **Quick actions**: Duże przyciski do szybkiego dostępu do głównych funkcji
  - "Utwórz nową strategię"
  - "Uruchom symulację"
  - "Generuj propozycje na losowanie"
- **Ostatnie 5 symulacji**: Mini lista z linkami do szczegółów

### 3. Sekcja Strategii (`:strategies`)

**Lista strategii**: Tabela/karty z wszystkimi strategiami użytkownika, wyświetlająca: nazwę, typ (manual/ai_generated), performance_score, liczbę symulacji. Przyciski akcji: Edytuj, Usuń, Zobacz szczegóły.

**Formularz tworzenia strategii**: Taby "Manualna" i "AI"
- **Tab "Manualna"**: Formularz z parametrami (ratio parzyste/nieparzyste, ratio low/high, preferowane gorące/zimne liczby, wagi)
- **Tab "AI"**: Textarea na prompt (max 500 znaków z licznikiem), przycisk "Generuj strategię AI", sekcja wyników z loading state i obsługą błędów

**Widok szczegółów strategii**: Modal z pełnymi informacjami (nazwa, typ, rules, performance_score, reasoning dla AI), historią symulacji, przyciskami akcji (Edytuj, Usuń, Uruchom symulację).

**Mix strategii**: Checkboxy do zaznaczania 2-3 strategii na liście, przycisk "Utwórz mix" aktywny gdy spełnione warunki, modal z loading state podczas generowania przez AI, wyświetlenie wyniku z możliwością zapisu.

### 4. Sekcja Symulacji (`:simulations`)

**Formularz uruchomienia**: Wybór strategii (dropdown), wybór target draw (dropdown z datami), opcjonalne limity (max prób, timeout), przycisk "Uruchom symulację".

**Live tracking** (`:simulation_tracking`): Osobna podsekcja wyświetlana po uruchomieniu symulacji:
- Duży licznik prób (aktualizacja co 2 sekundy)
- Czas trwania (format MM:SS)
- Status z animacją spinnera dla "running"
- Aktualizacje przez LiveView messaging (`handle_info`)
- Po zakończeniu: automatyczne wyświetlenie wyniku (success/timeout) z możliwością powrotu do listy lub uruchomienia nowej

**Historia symulacji**: Lista wszystkich symulacji użytkownika, sortowana najnowsze na górze, z możliwością filtrowania po strategii i statusie. Każda pozycja zawiera: nazwę strategii, target draw, liczbę prób, czas trwania, status z kolorowym wskaźnikiem.

### 5. Sekcja Rankingu (`:ranking`)

Lista strategii posortowana według mediany prób (rosnąco - niższa = lepsza). Dla każdej strategii: pozycja w rankingu, nazwa, typ, mediana prób, liczba symulacji, performance_score. Top 3 strategie wyróżnione wizualnie (złoty/srebrny/brązowy badge). Strategie bez symulacji na końcu z oznaczeniem "Brak danych".

### 6. Sekcja Generatora (`:generator`)

**Identyfikacja top strategii**: Wyświetlenie top 3 strategii użytkownika. Jeśli brak symulacji: komunikat z ofertą wygenerowania nowej strategii przez AI lub uruchomienia symulacji.

**Konfiguracja**: Wybór strategii (z top 3 lub dowolnej), wybór liczby kuponów (slider/input: 1-10), przycisk "Generuj propozycje".

**Wyświetlenie kuponów**: N unikalnych zestawów liczb wyświetlonych jako wizualne "kule":
- Główne liczby (5 kul) w jednym rzędzie
- Euro liczby (2 kule) w drugim rzędzie
- Różne kolory dla głównych vs euro (np. niebieskie vs żółte)
- Każdy kupon w osobnej karcie z numeracją "Kupon 1", "Kupon 2", etc.
- Przycisk "Wylosuj inne" pod wszystkimi kuponami (regeneracja)

## Strategia integracji z API i zarządzania stanem

### Integracja z API

LiveView nie wykonuje bezpośrednich HTTP requests do API endpoints. Zamiast tego używa funkcji z Phoenix Context modules (np. `Strategies.create_strategy/2`, `Simulations.start_simulation/3`), które z kolei mogą wykorzystywać API endpoints jako backend. To zapewnia separację warstw i łatwiejsze testowanie.

### Zarządzanie stanem

**LiveView assigns**: Każda sekcja ma własne assigns (`@strategies`, `@simulations`, `@rankings`, `@coupons`). Dane ładowane w `mount/3` lub `handle_params/3` przez wywołania do Context modules.

**Real-time updates**: Dla live tracking symulacji wykorzystanie Phoenix PubSub. Task.async publikuje aktualizacje na kanał PubSub, LiveView subskrybuje kanał i aktualizuje assigns przez `handle_info/2`. Performance score strategii odświeżany po każdej nowej symulacji przez PubSub update, nie przez polling.

**Cache'owanie**: 
- Dane statyczne (draw dates, game types): cache'owane w assigns, odświeżane tylko przy mount
- Dane dynamiczne (strategie, symulacje, ranking): świeże przy przełączeniu sekcji, cache'owane w assigns podczas sesji LiveView
- Dane historyczne (draws): cache'owane 5-10 minut (aktualizowane ręcznie ~1x tygodniowo)
- Hot/cold numbers analysis: zawsze świeże
- Performance score: przez PubSub, nie polling

### Paginacja

Paginacja po stronie serwera przez query parameters API (`page`, `per_page`). UI wyświetla paginację na dole listy (DaisyUI `join` z przyciskami numerów stron). Domyślnie 20 elementów na stronę dla strategii i symulacji. Ranking: top 10 domyślnie z możliwością "Pokaż więcej" (expandable list).

## Kwestie dotyczące responsywności, dostępności i bezpieczeństwa

### Responsywność

**Nawigacja**: 
- Desktop (>768px): Navbar poziomy zawsze widoczny na górze
- Mobile (≤768px): Hamburger menu (DaisyUI `drawer`) z ikoną menu w lewym górnym rogu
- Aktywna sekcja wyróżniona wizualnie (`btn-active` w DaisyUI) w obu wersjach

**Komponenty**: Wszystkie sekcje responsywne z Tailwind breakpoints (`sm:`, `md:`, `lg:`). Formularze w jednej kolumnie na mobile, kule kuponów mogą być mniejsze i układane w dwóch rzędach jeśli nie mieszczą się w jednym.

### Dostępność (a11y)

**Podstawowe wymagania MVP1**:
- Semantyczne tagi HTML (`<nav>`, `<main>`, `<section>`)
- Właściwe nagłówki hierarchiczne (`h1` → `h2` → `h3`)
- Alt text dla ikon (Heroicons)
- Aria-labels dla przycisków bez tekstu
- Focus states widoczne dla klawiatury (Tailwind `focus:ring`)
- Kontrast kolorów zgodny z WCAG AA (DaisyUI motywy zapewniają)
- Powiązane `<label>` z polami input
- Komunikaty błędów powiązane z polami przez `aria-describedby`
- `aria-live="polite"` dla live tracking aktualizacji

MVP1 nie wymaga pełnej zgodności WCAG AAA, ale podstawowe standardy powinny być spełnione.

### Bezpieczeństwo i autoryzacja

**Autoryzacja w UI**: 
- Dla niezalogowanych: tylko sekcja `:landing` widoczna
- Próba dostępu do chronionych sekcji: `on_mount` hook sprawdza `assigns.current_user` i przekierowuje na landing jeśli `nil`
- Po zalogowaniu: automatyczne przełączenie na `:dashboard`
- Wylogowanie: czyszczenie assigns i przełączenie na `:landing`

**Obsługa błędów autoryzacji**:
- 401 Unauthorized: Alert na górze strony "Sesja wygasła. Zaloguj się ponownie." z przekierowaniem na login
- 403 Forbidden / 404 Not Found: Komunikat "Nie masz dostępu do tego zasobu" z przyciskiem powrotu do dashboard

**Komunikaty błędów API**:
- 400 Bad Request (validation): Błędy inline przy polach formularza (DaisyUI `label-text` z klasą `text-error`)
- 429 Too Many Requests (rate limit): Alert z komunikatem i `retry_after`
- 503 Service Unavailable (AI timeout): Alert z komunikatem i przyciskiem retry + link do formularza manualnego
- 500 Internal Server Error: Ogólny komunikat z możliwością zgłoszenia błędu (post-MVP)

Wszystkie błędy logowane po stronie serwera z `request_id` dla debugowania, ale użytkownik widzi tylko przyjazne komunikaty.

## System komunikatów i feedback

### Flash Messages (Toast Notifications)

Phoenix flash messages (`put_flash`) wyświetlane jako toast notifications (DaisyUI `toast`) w prawym górnym rogu ekranu. Automatyczne znikanie po 5 sekundach lub po kliknięciu X. Typy: `:info` (niebieski), `:success` (zielony), `:error` (czerwony), `:warning` (żółty). Flash messages dla wszystkich akcji użytkownika: "Strategia utworzona pomyślnie", "Symulacja uruchomiona", "Błąd podczas generowania strategii przez AI".

### Loading States

Różne poziomy loading states dla różnych operacji:
- **Szybkie (<1s)**: Subtle loading indicator (przycisk z `phx-click-loading` pokazuje spinner w przycisku)
- **Średnie (1-5s)**: Loading overlay z komunikatem (DaisyUI `loading` + tekst)
- **Długie (>5s, np. symulacje)**: Progress indicator z aktualizacjami (live tracking z licznikiem prób)

Wszystkie operacje mają timeout handling. Loading states blokują interakcję użytkownika z formularzem/akcjami aby zapobiec duplikatom requestów.

### Komunikaty dla wolnych połączeń

Jasne komunikaty czasu trwania: "Generowanie strategii przez AI...", "Uruchamianie symulacji...", "To może potrwać kilka sekund". Dla długo działających operacji (symulacje >30s): dodatkowy komunikat "Symulacja może potrwać do 5 minut. Możesz zamknąć przeglądarkę - symulacja kontynuuje w tle."

## Obsługa utraty połączenia

LiveView automatycznie wykrywa utratę połączenia przez WebSocket i wyświetla komunikat "Utracono połączenie. Próba ponownego połączenia..." z animacją. Po ponownym połączeniu LiveView automatycznie synchronizuje stan z serwerem przez `handle_info(:after_join, socket)`. Symulacja kontynuuje działanie na serwerze, więc po ponownym połączeniu użytkownik zobaczy aktualny stan (running/success/timeout). Nie potrzeba dodatkowej logiki - LiveView to obsługuje out of the box.

## Struktura komponentów

Wszystkie komponenty UI zdefiniowane w `core_components.ex` jako funkcje komponentów Phoenix. Wykorzystanie komponentów DaisyUI jako podstawy z Tailwind CSS v4 utility classes dla custom styling i spacing. Kolory zgodne z motywem DaisyUI (light/dark), z możliwością przełączania przez `data-theme` attribute. Ikony przez `<.icon>` component z Heroicons. Spójna typografia przez Tailwind typography plugin lub custom CSS variables. Wszystkie interakcje z subtelnymi animacjami (transition) dla lepszego UX.

</ui_architecture_planning_summary>

<unresolved_issues>

1. **Szczegóły implementacji modali**: Czy modale powinny być renderowane jako osobne LiveComponents czy jako funkcjonalne komponenty z `@show_modal` assign? Wymaga decyzji technicznej podczas implementacji.

2. **Granice cache'owania**: Dokładne TTL dla cache'owania różnych typów danych (draws, hot/cold analysis) mogą wymagać dostrojenia w oparciu o rzeczywiste wzorce użycia.

3. **Paginacja dla bardzo długich list**: W MVP1 paginacja wystarczy, ale dla post-MVP może być potrzebne rozważenie infinite scroll dla lepszego UX przy bardzo długich listach symulacji.

4. **Theme switching UX**: Mechanizm przełączania motywu light/dark (przycisk, automatyczne wykrywanie preferencji systemowych) nie został szczegółowo określony - wymaga decyzji projektowej.

5. **Mobile menu drawer**: Szczegóły animacji i zachowania drawer na mobile (slide-in, overlay, zamykanie po kliknięciu linku) mogą wymagać dopracowania podczas implementacji.

6. **Error reporting dla użytkowników**: W MVP1 brak mechanizmu zgłaszania błędów przez użytkowników (wspomniane jako post-MVP). Może być potrzebne podstawowe rozwiązanie dla krytycznych błędów.

7. **Accessibility testing**: Podczas implementacji będzie potrzebne przetestowanie z rzeczywistymi narzędziami a11y (screen readers, keyboard navigation) aby upewnić się że wszystkie wymagania są spełnione.

8. **Performance monitoring**: W MVP1 brak szczegółowego planu monitorowania wydajności UI (czas renderowania, czas ładowania sekcji). Może być przydatne podstawowe logging dla identyfikacji bottlenecków.

</unresolved_issues>

</conversation_summary>

