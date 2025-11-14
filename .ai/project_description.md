### Główny problem
Użytkownicy chcą w ciekawy i edukacyjny sposób testować różne strategie typowania liczb w Eurojackpot, obserwować statystyki trafień oraz eksperymentować z mieszaniem strategii. Obecnie nie ma narzędzia, które umożliwiałoby:
- generowanie propozycji liczb zgodnie z wybranymi strategiami (losowa, parzyste/nieparzyste, low/high, gorące/zimne liczby, zrównoważony rozkład), w tym automatycznie przez AI,
- symulowanie skuteczności strategii na danych historycznych i zliczanie liczby prób do trafienia,
- uruchamianie równoległych multisymulacji na wielu historycznych losowaniach jednocześnie,
- śledzenie postępu i wyników w czasie rzeczywistym z limitami czasowymi/prób,
- porównywanie i wybieranie najlepszych strategii oraz mixów strategii,
- generowanie propozycji liczb na najbliższe losowanie na podstawie najskuteczniejszych strategii.

---

### Najmniejszy zestaw funkcjonalności
1. **Autoryzacja użytkowników**
   - Prosty system kont użytkowników (email/hasło) do przechowywania konfiguracji oraz historii symulacji
   
2. **Strategie (CRUD)**
   - Tworzenie, przeglądanie, edycja i usuwanie strategii
   - Podstawowe typy strategii:
     - Losowa
     - Parzyste/nieparzyste (kontrolowany balans)
     - Low/high (równomierny rozkład 1-25 vs 26-50)
     - Gorące/zimne liczby (analiza danych historycznych)
     - Zrównoważony rozkład (mix powyższych)
   - Automatyczne generowanie strategii przez AI na podstawie danych historycznych
   - Automatyczne generowanie strategii przez AI na podstawie wprowadzanego tekstu
   - Podstawowe mieszanie kilku strategii (tworzenie hybryd)
   
3. **Dane historyczne Eurojackpot**
   - Import i przechowywanie historycznych losowań (minimum 100 ostatnich)
   - Możliwość dodawania nowych wyników ręcznie lub przez import
   
4. **Symulacje**
   - Celem jest dobieranie najbardziej skutecznych stategii - za pomocą AI - mniej prób by trafić stopień I
   - **Pojedyncza symulacja:** test strategii na jednym historycznym losowaniu
   - **Multisymulacja:** równoległe uruchomienie 3-10 symulacji na różnych historycznych losowaniach
   - Zliczanie liczby prób potrzebnych do trafienia głównej wygranej (5+2)
   - **MVP śledzi TYLKO stopień I (5+2)** - inne stopnie wygranej w przyszłości
   - Limity bezpieczeństwa: timeout (np. 300s) LUB max liczba prób (np. 1M)
   - Live tracking postępu symulacji (liczba prób w czasie rzeczywistym przez LiveView)
   
5. **Ranking i analiza wyników**
   - Zapisywanie wyników symulacji (strategia, liczba prób, czas, status)
   - Ranking pojedynczych strategii (które najszybciej trafiają)
   - **Ranking mixów strategii** po multisymulacjach (które kombinacje najlepsze)
   - Wyświetlanie statystyk: średnia liczba prób, najlepszy/najgorszy wynik
   
6. **Generator propozycji na najbliższe losowanie**
   - Generowanie zestawu 5 liczb (1-50) + 2 euro liczby (1-12)
   - Bazowanie na najskuteczniejszych strategiach z multisymulacji
   - Możliwość wygenerowania 5-10 różnych kuponów
   
7. **Dashboard LiveView**
   - Widok główny z listą strategii i przyciskami akcji
   - Uruchamianie pojedynczej symulacji lub multisymulacji
   - Real-time monitoring postępu (liczniki prób, procent ukończenia)
   - Historia symulacji z wynikami
   - Ranking strategii i mixów
   - Generator kuponów na najbliższe losowanie

---

### Co NIE wchodzi w zakres MVP
- Dodatkowe gry losowe (Multi Multi, Lotto, Keno itp.)
- Zaawansowane algorytmy genetyczne (MVP: tylko podstawowe mieszanie kilku strategii)
- Automatyczna ewolucja strategii w wielu pokoleniach
- Przyciskiem "Stop" do przerwania
- Multisymulacje na >10 losowaniach równolegle (MVP: max 10)
- **Śledzenie wszystkich stopni wygranej podczas symulacji:**
  - Stopień II (5+1) - przy której próbie trafiono
  - Stopień III (5+0) - przy której próbie trafiono
  - Stopień IV (4+2) - przy której próbie trafiono
  - Stopień V (4+1) - przy której próbie trafiono
  - Stopień VI (3+2) - przy której próbie trafiono
  - Stopień VII (4+0) - przy której próbie trafiono
  - Zliczanie ile razy każdy stopień wygranej został trafiony przed osiągnięciem głównej wygranej (5+2)
  - Statystyki: średnia liczba prób do każdego stopnia, rozkład trafień
  - **MVP śledzi TYLKO główną wygraną (5+2)**, tracking wszystkich stopni to rozbudowa post-MVP
- Zaawansowana analiza i wizualizacja statystyk (wykresy trendu, heatmapy, korelacje)
- Automatyczny import wyników z API Totalizatora Sportowego
- Integracja z systemami hazardowymi lub płatnościami
- Współdzielenie strategii i wyników między użytkownikami
- Wersje mobilne
- Eksport raportów do PDF/Excel
- Powiadomienia email/push o ukończonych symulacjach
- Machine Learning do predykcji (MVP: tylko podstawowe reguły + proste AI sugestie)

---

### Kryteria sukcesu

**Funkcjonalne:**
- Użytkownik może założyć konto i zalogować się poprawnie
- Użytkownik może wykonać pełny CRUD na strategiach (utworzyć, edytować, usunąć, przeglądać)
- Użytkownik może stworzyć strategię ręcznie LUB otrzymać strategię wygenerowaną przez AI
- Użytkownik może uruchomić pojedynczą symulację na wybranej strategii i jednym historycznym losowaniu
- Użytkownik może uruchomić multisymulację (3-10 równoległych symulacji) na różnych historycznych losowaniach
- Symulacje mają limity (timeout LUB max liczba prób) i nie trwają w nieskończoność
- Użytkownik widzi w czasie rzeczywistym postęp symulacji (liczba prób) przez LiveView
- Wynik każdej symulacji (liczba prób, czas, status: sukces/timeout) jest zapisany w bazie danych
- Dashboard wyświetla ranking pojedynczych strategii (najskuteczniejsze według średniej liczby prób)
- Dashboard wyświetla ranking mixów strategii po multisymulacjach
- Użytkownik może wygenerować propozycje liczb na najbliższe losowanie bazując na najlepszych strategiach

**Wydajnościowe:**
- Minimum 50% symulacji kończy się sukcesem (trafienie 5+2) w limicie prób
- Multisymulacja na 5 losowaniach kończy się w <2 minuty
