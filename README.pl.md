# Numbers Evolution

### 🌐 Języki

[English](README.md) | [Polski](README.pl.md)

[![Status Projektu](https://img.shields.io/badge/status-w%20rozwoju-yellow)](https://github.com)
[![Tech Stack](https://img.shields.io/badge/Elixir-4B275F?logo=elixir&logoColor=white)](https://elixir-lang.org/)
[![Phoenix](https://img.shields.io/badge/Phoenix-FD4F00?logo=phoenixframework&logoColor=white)](https://www.phoenixframework.org/)
[![LiveView](https://img.shields.io/badge/LiveView-real--time-brightgreen)](https://hexdocs.pm/phoenix_live_view/)

> Edukacyjna aplikacja webowa do testowania i analizy strategii typowania liczb w Eurojackpot ze wsparciem sztucznej inteligencji

## 📋 Spis Treści

- [O Projekcie](#o-projekcie)
- [Stack Technologiczny](#stack-technologiczny)
- [Rozpoczęcie Pracy](#rozpoczęcie-pracy)
- [Dostępne Skrypty](#dostępne-skrypty)
- [Zakres Projektu](#zakres-projektu)
- [Status Projektu](#status-projektu)
- [Architektura](#architektura)
- [Bezpieczeństwo](#bezpieczeństwo)
- [Licencja](#licencja)

## 🎯 O Projekcie

Numbers Evolution to edukacyjna aplikacja webowa umożliwiająca użytkownikom testowanie i analizę różnych strategii typowania liczb w grze Eurojackpot. Zbudowana jako projekt zaliczeniowy dla kursu 10xdevs, demonstruje możliwości Phoenix LiveView, integracji AI oraz programowania współbieżnego w Elixir.

### Kluczowe Funkcje

- **Zarządzanie Strategiami**: Tworzenie, edytowanie i zarządzanie strategiami typowania ręcznie lub z pomocą AI
- **Generowanie przez AI**: Tworzenie strategii przy użyciu promptów w języku naturalnym (OpenAI GPT-4 Turbo lub Claude 3.5 Sonnet)
- **Symulacje w Czasie Rzeczywistym**: Uruchamianie symulacji na historycznych danych losowań ze śledzeniem postępu na żywo
- **Analityka Wydajności**: Porównywanie skuteczności strategii przy użyciu analizy statystycznej
- **Generator Kuponów**: Generowanie propozycji liczb na nadchodzące losowania w oparciu o najskuteczniejsze strategie
- **Multisymulacje**: Równoległe uruchamianie symulacji na wielu historycznych losowaniach (MVP2)

### Grupy Docelowe

- **Analityk Tomek**: Entuzjasta statystyki, który chce eksperymentować z różnymi parametrami strategii i odkrywać wzorce
- **Gracz Marek**: Regularny gracz Eurojackpot, który chce testować strategie bez wydawania pieniędzy na kupony

### Zastrzeżenie Edukacyjne

⚠️ **Aplikacja służy wyłącznie celom edukacyjnym i symulacyjnym.** Nie gwarantuje wygranej i nie jest oficjalnie powiązana z operatorami loterii. Używaj na własną odpowiedzialność.

## 🛠 Stack Technologiczny

### Główne Technologie

- **Backend**: [Elixir](https://elixir-lang.org/) z [Phoenix Framework](https://www.phoenixframework.org/)
- **Frontend**: [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/) (SPA w czasie rzeczywistym)
- **Baza Danych**: [PostgreSQL](https://www.postgresql.org/) ze wsparciem JSONB
- **AI Provider**: [OpenAI GPT-4 Turbo](https://openai.com/) lub [Claude 3.5 Sonnet](https://www.anthropic.com/)
- **Autoryzacja**: Phoenix `phx.gen.auth`
- **Deployment**: [Fly.io](https://fly.io/) (post-MVP)

### Kluczowe Biblioteki i Narzędzia

- **Ecto**: Wrapper bazy danych i generator zapytań
- **Task.async**: Współbieżne wykonywanie symulacji
- **Phoenix PubSub**: Komunikacja w czasie rzeczywistym dla śledzenia na żywo
- **Jason**: Kodowanie/dekodowanie JSON
- **Bcrypt**: Bezpieczne hashowanie haseł

### Dlaczego Ten Stack?

- **Phoenix LiveView**: Zapewnia aktualizacje w czasie rzeczywistym bez skomplikowanej implementacji WebSocket
- **Elixir Concurrency**: Idealny do uruchamiania wielu symulacji równolegle przy użyciu lekkich procesów
- **BEAM VM**: Wbudowana tolerancja błędów i doskonała skalowalność
- **PostgreSQL JSONB**: Elastyczny schemat dla dynamicznych reguł strategii

## 🚀 Rozpoczęcie Pracy

### Wymagania Wstępne

- Elixir 1.14+ oraz Erlang/OTP 25+
- PostgreSQL 14+
- Node.js 16+ (do kompilacji assetów)
- Klucz API OpenAI lub Anthropic (dla funkcji AI)

### Instalacja

1. **Sklonuj repozytorium**
   ```bash
   git clone https://github.com/yourusername/numbers_evolution.git
   cd numbers_evolution
   ```

2. **Zainstaluj zależności**
   ```bash
   mix deps.get
   mix deps.compile
   ```

3. **Zainstaluj zależności Node.js**
   ```bash
   cd assets && npm install && cd ..
   ```

4. **Skonfiguruj zmienne środowiskowe**
   
   Utwórz plik `.env` lub wyeksportuj następujące zmienne:
   ```bash
   export DATABASE_URL="postgresql://user:password@localhost/numbers_evolution_dev"
   export OPENAI_API_KEY="twoj_klucz_api_openai"
   # LUB
   export CLAUDE_API_KEY="twoj_klucz_api_claude"
   export SECRET_KEY_BASE="wygeneruj_przez_mix_phx_gen_secret"
   ```

5. **Utwórz i zmigruj bazę danych**
   ```bash
   mix ecto.create
   mix ecto.migrate
   ```

6. **Załaduj dane historyczne losowań**
   ```bash
   mix run priv/repo/seeds.exs
   ```

7. **Uruchom serwer Phoenix**
   ```bash
   mix phx.server
   ```

8. **Odwiedź aplikację**
   
   Przejdź do [`localhost:4000`](http://localhost:4000) w przeglądarce.

### Setup z Dockerem (Alternatywnie)

```bash
docker-compose up -d
mix ecto.create
mix ecto.migrate
mix phx.server
```

## 📜 Dostępne Skrypty

### Rozwój

- `mix phx.server` - Uruchom serwer Phoenix
- `mix phx.server --no-halt` - Uruchom serwer w trybie produkcyjnym
- `iex -S mix phx.server` - Uruchom serwer z interaktywną konsolą Elixir

### Baza Danych

- `mix ecto.create` - Utwórz bazę danych
- `mix ecto.migrate` - Uruchom migracje bazy danych
- `mix ecto.rollback` - Cofnij ostatnią migrację
- `mix ecto.reset` - Usuń, utwórz i zmigruj bazę danych
- `mix run priv/repo/seeds.exs` - Załaduj bazę danych historycznymi danymi losowań

### Testowanie

- `mix test` - Uruchom wszystkie testy
- `mix test --cover` - Uruchom testy z raportem pokrycia
- `mix test test/path/to/test.exs` - Uruchom konkretny plik testowy

### Jakość Kodu

- `mix format` - Formatuj kod według przewodnika stylu Elixir
- `mix credo` - Uruchom statyczną analizę kodu
- `mix dialyzer` - Uruchom sprawdzanie typów (wymaga wstępnej konfiguracji)

### Autoryzacja

- `mix phx.gen.auth Accounts User users` - Wygeneruj system autoryzacji (już wykonane)

### Produkcja

- `mix phx.digest` - Skompiluj i przygotuj assety dla produkcji
- `MIX_ENV=prod mix release` - Zbuduj release produkcyjny

## 📦 Zakres Projektu

### Funkcje MVP1 (6 tygodni)

#### ✅ Autoryzacja Użytkowników (F7)
- Rejestracja i logowanie użytkowników (email + hasło)
- Zarządzanie sesją z bezpiecznymi cookies
- Funkcja zmiany hasła
- Izolacja danych per użytkownik

#### ✅ Zarządzanie Strategiami (F1)
- Pełne operacje CRUD dla strategii
- Ręczne tworzenie strategii z parametrami:
  - Ratio parzyste/nieparzyste dla głównych liczb
  - Ratio low/high (1-25 vs 26-50)
  - Preferencje gorących/zimnych liczb
  - Ważone kryteria
- Generowanie strategii przez AI poprzez prompty w języku naturalnym
- Walidacja strategii (wagi sumują się do 1.0, prawidłowe ratio)
- Mieszanie strategii (łączenie 2-3 strategii w hybrydy)

#### ✅ Dane Historyczne (F6)
- 100-200 historycznych losowań Eurojackpot załadowanych
- Uniwersalna struktura danych dla przyszłych typów gier
- Ręczne aktualizacje przez migracje (cotygodniowe)

#### ✅ Silnik Symulacji (F2)
- Wykonywanie pojedynczej symulacji na historycznych losowaniach
- Limity bezpieczeństwa:
  - Domyślny timeout: 300 sekund
  - Domyślna max liczba prób: 1,000,000
- Wykonywanie w tle z `Task.async`
- Wykrywanie wygranej: 5 głównych liczb + 2 euro liczby (5+2)

#### ✅ Śledzenie Na Żywo (F3)
- Aktualizacje postępu w czasie rzeczywistym co 2 sekundy
- Komunikacja LiveView dla płynnych aktualizacji
- Wyświetlanie: licznik prób, czas trwania, status
- Symulacje kontynuują działanie nawet po zamknięciu przeglądarki

#### ✅ Ranking i Analityka (F4)
- Obliczanie wskaźnika wydajności (mediana prób)
- Ranking strategii według skuteczności
- Historia symulacji z filtrowaniem
- Ranking mixów po multisymulacjach

#### ✅ Generator Kuponów (F5)
- Identyfikacja top 3 najskuteczniejszych strategii
- Generowanie 1-10 unikalnych propozycji kuponów
- Wizualizacja "kul" z numerami
- Możliwość regeneracji

#### ✅ Dashboard (F8)
- Doświadczenie single-page application (SPA)
- Przegląd statystyk użytkownika
- Szybkie akcje dla typowych zadań
- Nawigacja między sekcjami bez przeładowania strony

### Funkcje MVP2 (Rozszerzone)

#### 🔄 Multisymulacje (F-MS)
- Uruchamianie 3-10 równoległych symulacji jednocześnie
- Każda symulacja na innym historycznym losowaniu
- Agregowane statystyki i analiza
- Śledzenie na żywo wszystkich równoległych procesów

### Poza Zakresem (MVP1)

- ❌ Dodatkowe gry losowe (Multi Multi, Lotto, Keno)
- ❌ Zaawansowane algorytmy ewolucyjne
- ❌ Przycisk Stop dla działających symulacji
- ❌ Śledzenie wszystkich stopni wygranej (tylko 5+2 w MVP1)
- ❌ Zaawansowane wizualizacje (wykresy, heatmapy)
- ❌ Automatyczny import danych losowań
- ❌ Publiczne API
- ❌ Funkcje społecznościowe (udostępnianie strategii)
- ❌ Aplikacje mobilne (iOS/Android) - tylko responsywny web
- ❌ Export do PDF/Excel
- ❌ Powiadomienia email/push
- ❌ Predykcje machine learning
- ❌ Panel administracyjny UI

## 📊 Status Projektu

### Obecna Faza: Rozwój

**Timeline**: 6-tygodniowy cykl rozwoju MVP1

#### Tydzień 1-2: Fundamenty ✅
- [x] Setup projektu i konfiguracja
- [x] Schemat bazy danych i migracje
- [x] System autoryzacji (phx.gen.auth)
- [x] Podstawowy layout i nawigacja
- [x] Załadowanie historycznych danych losowań

#### Tydzień 3: Moduł Strategii 🔄
- [ ] Operacje CRUD strategii
- [ ] Formularz strategii manualnej
- [ ] Strategie szablonowe (15 presetów)
- [ ] Logika walidacji strategii

#### Tydzień 4: Integracja AI 🔜
- [ ] Moduł serwisu AI
- [ ] Prompt engineering dla generowania strategii
- [ ] Parsowanie i walidacja odpowiedzi JSON
- [ ] Obsługa błędów i fallbacki
- [ ] Rate limiting (5 generacji/użytkownik/dzień)

#### Tydzień 5: Silnik Symulacji 🔜
- [ ] Główny algorytm symulacji
- [ ] Implementacja Task.async
- [ ] Egzekwowanie timeout i limitów
- [ ] Persystencja wyników
- [ ] Integracja śledzenia na żywo

#### Tydzień 6: Finalne Funkcje 🔜
- [ ] System rankingowy
- [ ] Obliczanie wskaźnika wydajności
- [ ] Generator kuponów
- [ ] Dopracowanie dashboardu
- [ ] Testowanie i dokumentacja

#### Post-MVP1
- [ ] Deployment na Fly.io
- [ ] Multisymulacje (MVP2)
- [ ] Potwierdzenie email
- [ ] Integracja OAuth (opcjonalnie)

### Metryki Sukcesu

**Sukces Funkcjonalny**:
- ✅ Użytkownik może zarejestrować się, zalogować i zarządzać kontem
- ✅ Użytkownik może wykonać pełny CRUD na strategiach
- ⏳ Użytkownik może tworzyć strategie ręcznie lub przez AI
- ⏳ Użytkownik może uruchomić pojedynczą symulację na danych historycznych
- ⏳ Użytkownik może uruchomić multisymulacje (MVP2)
- ⏳ Śledzenie postępu w czasie rzeczywistym działa przez LiveView
- ⏳ Rankingi wyświetlają się według mediany prób
- ⏳ Generator kuponów produkuje prawidłowe propozycje

**Sukces Wydajnościowy**:
- Cel: 50%+ symulacji kończy się sukcesem w ramach limitów
- Cel: Multisymulacja (5 losowań) kończy się w <2 minuty
- Cel: >95% symulacji bez błędów
- Cel: Wszystkie symulacje respektują timeout (≤300s) i limity prób (≤1M)

**Sukces Produktowy**:
- Cel: >60% strategii to strategie generowane przez AI
- Cel: Średnio >5 symulacji na użytkownika w pierwszym tygodniu
- Cel: >40% użytkowników korzysta z generatora kuponów

## 🏗 Architektura

### Wzorzec Context

Aplikacja podąża za wzorcem context Phoenix dla czystego rozdzielenia odpowiedzialności:

```
lib/numbers_evolution/
├── accounts/          # Autoryzacja i zarządzanie użytkownikami
├── strategies/        # CRUD strategii i generowanie AI
├── simulations/       # Silnik symulacji i śledzenie
├── draws/             # Historyczne dane losowań
└── analytics/         # Rankingi i metryki wydajności
```

### Schemat Bazy Danych

**Główne Tabele**:
- `users` - Konta użytkowników i autoryzacja
- `strategies` - Strategie tworzone przez użytkowników z regułami JSONB
- `draws` - Historyczne wyniki losowań
- `simulations` - Uruchomienia symulacji i wyniki

### Model Współbieżności

- **Zadania Symulacji**: Każda symulacja działa w izolowanym procesie `Task.async`
- **Procesy LiveView**: Jeden proces na połączonego użytkownika dla aktualizacji w czasie rzeczywistym
- **Komunikacja PubSub**: Komunikacja między zadaniami symulacji a procesami LiveView

### Przepływ Integracji AI

1. Użytkownik wysyła prompt w języku naturalnym
2. System pobiera ostatnie 32 losowania
3. System analizuje gorące/zimne liczby
4. Strukturalny prompt wysyłany do providera AI (OpenAI lub Claude)
5. AI zwraca JSON z parametrami strategii
6. JSON jest walidowany i parsowany
7. Strategia zapisana w bazie danych z typem: `ai_generated`

## 🔒 Bezpieczeństwo

### Zaimplementowane

- ✅ **Hashowanie Haseł**: Bcrypt z odpowiednim work factor
- ✅ **Ochrona CSRF**: Automatyczne generowanie i walidacja tokenów
- ✅ **Ochrona SQL Injection**: Parametryzowane zapytania Ecto
- ✅ **Ochrona XSS**: Automatyczne escapowanie Phoenix.HTML
- ✅ **Bezpieczne Sesje**: Flagi HttpOnly i Secure dla cookies
- ✅ **Izolacja Danych**: Wszystkie zapytania scopowane przez user_id

### Zalecane Ulepszenia

- 🔐 **Walidacja Siły Hasła**: Min 8 znaków, 1 cyfra, 1 znak specjalny
- 🔐 **Rate Limiting AI**: 5 generacji na użytkownika dziennie
- 🔐 **Walidacja Promptów**: Limit maksymalnie 500 znaków
- 🔐 **Potwierdzenie Email**: Zapobieganie spamowym kontom
- 🔐 **Walidacja Schematu JSON**: Walidacja struktury reguł strategii

### Uwagi Produkcyjne

Dla wdrożenia produkcyjnego z >50 użytkownikami:
- Zaimplementuj wszystkie zalecane ulepszenia bezpieczeństwa
- Włącz potwierdzenie email
- Dodaj audit logging
- Rozważ 2FA dla wrażliwych kont
- Monitoruj koszty AI i egzekwuj ostrzejsze rate limity

## 🤝 Współpraca

To jest projekt edukacyjny dla kursu 10xdevs. Wkład mile widziany po ukończeniu MVP1.

### Wytyczne Deweloperskie

1. Przestrzegaj przewodnika stylu Elixir (używaj `mix format`)
2. Pisz testy dla nowych funkcji
3. Upewnij się, że wszystkie testy przechodzą przed wysłaniem PR
4. Aktualizuj dokumentację w razie potrzeby
5. Stosuj wzorce context Phoenix

## 📄 Licencja

Projekt jest open source i dostępny na licencji MIT.

## 📞 Kontakt

Projekt rozwijany w ramach kursu [10xdevs](https://10xdevs.pl/).

---

**Uwaga**: Ta aplikacja jest czysto edukacyjna i nie zachęca do hazardu. Demonstruje możliwości Phoenix LiveView, integracji AI oraz wzorców współbieżności w Elixir.

