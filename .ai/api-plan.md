# REST API Plan - Numbers Evolution

**Version:** 1.0  
**Date:** November 15, 2025  
**Framework:** Phoenix/Elixir  
**Database:** PostgreSQL

---

## 1. Overview

This REST API plan supports the Numbers Evolution application, an educational lottery strategy testing platform. While the primary interface uses Phoenix LiveView, this API provides:

- Backend services for LiveView components
- AI integration endpoints
- Future mobile app support
- External integrations
- Background job triggers

### Architecture Notes

- **Primary Interface:** Phoenix LiveView (WebSocket-based)
- **API Style:** RESTful with JSON payloads
- **Authentication:** Session-based (Phoenix.Token)
- **Authorization:** User-scoped queries (Context pattern)
- **Real-time Updates:** Phoenix PubSub + LiveView (not REST)

---

## 2. Resources

| Resource | Database Table | Description |
|----------|---------------|-------------|
| Users | `users` | User accounts and authentication |
| Strategies | `strategies` | Lottery number generation strategies |
| Draws | `draws` | Historical lottery draw results |
| Simulations | `simulations` | Strategy simulation runs |
| Events | `events` | User activity and system events |
| Coupons | N/A | Generated number sets (ephemeral) |

---

## 3. Authentication & Authorization

### Authentication Mechanism

**Session-based authentication** using Phoenix.Token:

- Registration/login handled by `phx.gen.auth`
- Session stored in encrypted cookies
- CSRF protection enabled by default
- Token-based API access for non-browser clients

### Token-Based API Access

For programmatic access (mobile apps, integrations):

```
POST /api/auth/token
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}

Response:
{
  "token": "SFMyNTY.g3QA...",
  "expires_at": "2025-11-22T10:00:00Z",
  "user": {
    "id": "uuid",
    "email": "user@example.com"
  }
}
```

### Authorization Rules

1. **User Scoping:** All queries automatically filtered by `user_id`
2. **Context Pattern:** Authorization enforced in Phoenix Contexts
3. **Public Resources:** Only `draws` table is public
4. **Rate Limiting:** 
   - AI generation: 5 requests/user/day
   - API calls: 100 requests/minute/user

### Headers

All authenticated requests must include:

```
Authorization: Bearer <token>
Content-Type: application/json
```

---

## 4. Core Endpoints

### 4.1 Users

#### Register User

```
POST /api/users/register

Request:
{
  "email": "user@example.com",
  "password": "password123",
  "password_confirmation": "password123"
}

Success Response (201 Created):
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "confirmed_at": null,
    "inserted_at": "2025-11-15T10:00:00Z"
  },
  "token": "SFMyNTY.g3QA..."
}

Error Responses:
400 Bad Request - Validation errors
{
  "errors": {
    "email": ["has already been taken"],
    "password": ["should be at least 8 character(s)"]
  }
}
```

#### Get Current User

```
GET /api/users/me

Success Response (200 OK):
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "preferences": {
      "theme": "dark",
      "notifications_enabled": true
    },
    "stats": {
      "strategies_count": 5,
      "simulations_count": 23,
      "best_strategy": {
        "id": "uuid",
        "name": "Hot Numbers Focus",
        "performance_score": 125430.5
      }
    },
    "inserted_at": "2025-11-15T10:00:00Z"
  }
}

Error Responses:
401 Unauthorized - Invalid or expired token
```

#### Update User Preferences

```
PATCH /api/users/me

Request:
{
  "preferences": {
    "theme": "dark",
    "notifications_enabled": false
  }
}

Success Response (200 OK):
{
  "data": {
    "id": "uuid",
    "email": "user@example.com",
    "preferences": {
      "theme": "dark",
      "notifications_enabled": false
    }
  }
}
```

#### Change Password

```
POST /api/users/me/password

Request:
{
  "current_password": "oldpass123",
  "password": "newpass456",
  "password_confirmation": "newpass456"
}

Success Response (200 OK):
{
  "message": "Password changed successfully"
}

Error Responses:
400 Bad Request - Current password incorrect
{
  "errors": {
    "current_password": ["is not valid"]
  }
}
```

---

### 4.2 Strategies

#### List User Strategies

```
GET /api/strategies
Query Parameters:
  - type: filter by type (manual|ai_generated)
  - status: filter by status (active|archived|deleted)
  - sort: sort field (performance_score|inserted_at|name)
  - order: sort order (asc|desc), default: asc
  - page: page number (default: 1)
  - per_page: items per page (default: 20, max: 100)

Success Response (200 OK):
{
  "data": [
    {
      "id": "uuid",
      "name": "Hot Numbers Focus",
      "type": "manual",
      "status": "active",
      "rules": {
        "main_numbers": {
          "ratio_even_odd": [2, 3],
          "ratio_low_high": [3, 2],
          "weights": {
            "hot": 0.7,
            "cold": 0.1,
            "random": 0.2
          }
        },
        "euro_numbers": {
          "ratio_even_odd": [1, 1],
          "weights": {
            "hot": 0.6,
            "random": 0.4
          }
        }
      },
      "performance_score": 125430.5,
      "simulations_count": 10,
      "ai_prompt": null,
      "inserted_at": "2025-11-15T10:00:00Z",
      "updated_at": "2025-11-15T10:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total_count": 5,
    "total_pages": 1
  }
}
```

#### Get Strategy Details

```
GET /api/strategies/:id

Success Response (200 OK):
{
  "data": {
    "id": "uuid",
    "name": "Hot Numbers Focus",
    "type": "manual",
    "status": "active",
    "rules": { /* full rules object */ },
    "performance_score": 125430.5,
    "ai_prompt": null,
    "inserted_at": "2025-11-15T10:00:00Z",
    "updated_at": "2025-11-15T10:00:00Z",
    "simulations": [
      {
        "id": "uuid",
        "target_draw_id": "uuid",
        "target_draw_date": "2024-11-08",
        "attempts_count": 125430,
        "duration_seconds": 45.2,
        "status": "success",
        "completed_at": "2025-11-15T10:00:00Z"
      }
    ],
    "stats": {
      "simulations_count": 10,
      "success_count": 8,
      "timeout_count": 2,
      "median_attempts": 125430.5,
      "avg_duration": 42.3
    }
  }
}

Error Responses:
404 Not Found - Strategy not found or doesn't belong to user
```

#### Create Manual Strategy

```
POST /api/strategies

Request:
{
  "name": "My Custom Strategy",
  "type": "manual",
  "rules": {
    "main_numbers": {
      "ratio_even_odd": [2, 3],
      "ratio_low_high": [3, 2],
      "preferred_hot": [7, 23, 34],
      "preferred_cold": [1, 50],
      "weights": {
        "hot": 0.4,
        "cold": 0.2,
        "random": 0.4
      }
    },
    "euro_numbers": {
      "ratio_even_odd": [1, 1],
      "preferred": [3, 9],
      "weights": {
        "hot": 0.5,
        "random": 0.5
      }
    }
  }
}

Success Response (201 Created):
{
  "data": {
    "id": "uuid",
    "name": "My Custom Strategy",
    "type": "manual",
    "status": "active",
    "rules": { /* echoed rules */ },
    "performance_score": null,
    "inserted_at": "2025-11-15T10:00:00Z"
  }
}

Error Responses:
400 Bad Request - Validation errors
{
  "errors": {
    "name": ["can't be blank"],
    "rules.main_numbers.weights": ["must sum to 1.0"],
    "rules.main_numbers.ratio_even_odd": ["must sum to 5"]
  }
}

422 Unprocessable Entity - Business logic errors
{
  "error": "Strategy cannot generate valid number sets with these rules"
}
```

#### Generate Strategy with AI

```
POST /api/strategies/generate

Request:
{
  "prompt": "Create a balanced strategy focusing on recent hot numbers with some random variation",
  "game_type": "eurojackpot"
}

Success Response (201 Created):
{
  "data": {
    "id": "uuid",
    "name": "Balanced Hot Strategy",
    "type": "ai_generated",
    "status": "active",
    "rules": { /* AI-generated rules */ },
    "ai_prompt": "Create a balanced strategy...",
    "reasoning": "This strategy balances hot number trends from the last 32 draws with random variation to avoid over-fitting...",
    "performance_score": null,
    "inserted_at": "2025-11-15T10:00:00Z"
  }
}

Error Responses:
400 Bad Request - Invalid prompt
{
  "errors": {
    "prompt": ["should be at most 500 character(s)", "can't be blank"]
  }
}

429 Too Many Requests - Rate limit exceeded
{
  "error": "AI generation limit exceeded. You can generate 5 strategies per day. Try again tomorrow.",
  "retry_after": 43200
}

503 Service Unavailable - AI service error
{
  "error": "AI service temporarily unavailable. Please try again or create a manual strategy.",
  "fallback_action": "create_manual"
}
```

#### Update Strategy

```
PATCH /api/strategies/:id

Request:
{
  "name": "Updated Strategy Name",
  "rules": { /* updated rules */ }
}

Success Response (200 OK):
{
  "data": { /* updated strategy */ }
}

Error Responses:
403 Forbidden - Cannot modify AI-generated strategy rules
{
  "error": "AI-generated strategy rules cannot be modified. You can change the name or create a new strategy."
}
```

#### Delete Strategy (Soft Delete)

```
DELETE /api/strategies/:id

Success Response (204 No Content)

Error Responses:
404 Not Found - Strategy not found
```

#### Create Strategy Mix

```
POST /api/strategies/mix

Request:
{
  "name": "Hot + Cold Hybrid",
  "strategy_ids": [
    "uuid-1",
    "uuid-2",
    "uuid-3"
  ]
}

Success Response (201 Created):
{
  "data": {
    "id": "uuid",
    "name": "Hot + Cold Hybrid",
    "type": "ai_generated",
    "status": "active",
    "rules": { /* AI-merged rules */ },
    "reasoning": "This mix combines Strategy A's hot number focus with Strategy B's cold number contrarian approach...",
    "component_strategies": [
      {
        "id": "uuid-1",
        "name": "Hot Focus",
        "priority_weight": 0.5
      },
      {
        "id": "uuid-2",
        "name": "Cold Contrarian",
        "priority_weight": 0.3
      }
    ],
    "inserted_at": "2025-11-15T10:00:00Z"
  }
}

Error Responses:
400 Bad Request
{
  "errors": {
    "strategy_ids": ["must contain between 2 and 3 strategies"]
  }
}

409 Conflict - Incompatible strategies
{
  "error": "These strategies have conflicting rules that cannot be merged",
  "conflicts": [
    {
      "field": "main_numbers.ratio_even_odd",
      "strategy_1": "5:0 (all even)",
      "strategy_2": "0:5 (all odd)"
    }
  ]
}
```

---

### 4.3 Draws

#### List Historical Draws

```
GET /api/draws
Query Parameters:
  - game_type: filter by game type (eurojackpot|lotto|multi_multi)
  - from_date: start date (ISO 8601)
  - to_date: end date (ISO 8601)
  - page: page number (default: 1)
  - per_page: items per page (default: 50, max: 200)

Success Response (200 OK):
{
  "data": [
    {
      "id": "uuid",
      "draw_date": "2024-11-08",
      "game_type": "eurojackpot",
      "numbers": {
        "main_numbers": [1, 7, 23, 34, 50],
        "euro_numbers": [3, 9]
      },
      "source": "manual",
      "inserted_at": "2025-11-15T10:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 50,
    "total_count": 150,
    "total_pages": 3
  }
}
```

#### Get Draw Details

```
GET /api/draws/:id

Success Response (200 OK):
{
  "data": {
    "id": "uuid",
    "draw_date": "2024-11-08",
    "game_type": "eurojackpot",
    "numbers": {
      "main_numbers": [1, 7, 23, 34, 50],
      "euro_numbers": [3, 9]
    },
    "source": "manual",
    "inserted_at": "2025-11-15T10:00:00Z",
    "simulations_count": 45
  }
}
```

#### Get Latest Draw

```
GET /api/draws/latest?game_type=eurojackpot

Success Response (200 OK):
{
  "data": {
    "id": "uuid",
    "draw_date": "2024-11-08",
    "game_type": "eurojackpot",
    "numbers": {
      "main_numbers": [1, 7, 23, 34, 50],
      "euro_numbers": [3, 9]
    }
  }
}
```

#### Get Hot/Cold Numbers Analysis

```
GET /api/draws/analysis
Query Parameters:
  - game_type: required (eurojackpot|lotto|multi_multi)
  - period: number of recent draws to analyze (default: 32, max: 100)

Success Response (200 OK):
{
  "data": {
    "game_type": "eurojackpot",
    "analyzed_draws": 32,
    "date_range": {
      "from": "2024-04-01",
      "to": "2024-11-08"
    },
    "main_numbers": {
      "hot": [
        {"number": 7, "frequency": 12, "percentage": 37.5},
        {"number": 23, "frequency": 11, "percentage": 34.4},
        {"number": 34, "frequency": 10, "percentage": 31.3}
      ],
      "cold": [
        {"number": 1, "frequency": 2, "percentage": 6.3},
        {"number": 50, "frequency": 3, "percentage": 9.4}
      ],
      "all": [
        {"number": 1, "frequency": 2},
        /* ... all numbers 1-50 ... */
      ]
    },
    "euro_numbers": {
      "hot": [
        {"number": 3, "frequency": 15, "percentage": 46.9},
        {"number": 9, "frequency": 13, "percentage": 40.6}
      ],
      "cold": [
        {"number": 1, "frequency": 1, "percentage": 3.1}
      ],
      "all": [
        {"number": 1, "frequency": 1},
        /* ... all numbers 1-12 ... */
      ]
    }
  }
}
```

---

### 4.4 Simulations

#### List User Simulations

```
GET /api/simulations
Query Parameters:
  - strategy_id: filter by strategy
  - status: filter by status (pending|running|success|timeout|error|cancelled)
  - from_date: start date
  - to_date: end date
  - page: page number
  - per_page: items per page

Success Response (200 OK):
{
  "data": [
    {
      "id": "uuid",
      "strategy_id": "uuid",
      "strategy_name": "Hot Numbers Focus",
      "target_draw_id": "uuid",
      "target_draw_date": "2024-11-08",
      "attempts_count": 125430,
      "duration_seconds": 45.2,
      "status": "success",
      "result": {
        "matched_main": [1, 7, 23, 34, 50],
        "matched_euro": [3, 9],
        "attempts_count": 125430,
        "final_draw": {
          "main_numbers": [1, 7, 23, 34, 50],
          "euro_numbers": [3, 9]
        }
      },
      "started_at": "2025-11-15T10:00:00Z",
      "completed_at": "2025-11-15T10:00:45Z",
      "inserted_at": "2025-11-15T10:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total_count": 50,
    "total_pages": 3
  }
}
```

#### Get Simulation Details

```
GET /api/simulations/:id

Success Response (200 OK):
{
  "data": {
    "id": "uuid",
    "strategy": {
      "id": "uuid",
      "name": "Hot Numbers Focus",
      "type": "manual"
    },
    "target_draw": {
      "id": "uuid",
      "draw_date": "2024-11-08",
      "numbers": {
        "main_numbers": [1, 7, 23, 34, 50],
        "euro_numbers": [3, 9]
      }
    },
    "attempts_count": 125430,
    "duration_seconds": 45.2,
    "status": "success",
    "result": { /* full result object */ },
    "started_at": "2025-11-15T10:00:00Z",
    "completed_at": "2025-11-15T10:00:45Z"
  }
}
```

#### Start Simulation

```
POST /api/simulations

Request:
{
  "strategy_id": "uuid",
  "target_draw_id": "uuid",
  "options": {
    "max_attempts": 1000000,
    "timeout_seconds": 300
  }
}

Success Response (202 Accepted):
{
  "data": {
    "id": "uuid",
    "strategy_id": "uuid",
    "target_draw_id": "uuid",
    "status": "pending",
    "options": {
      "max_attempts": 1000000,
      "timeout_seconds": 300
    },
    "inserted_at": "2025-11-15T10:00:00Z"
  },
  "message": "Simulation queued for processing"
}

Error Responses:
400 Bad Request
{
  "errors": {
    "strategy_id": ["does not exist or doesn't belong to you"],
    "target_draw_id": ["does not exist"],
    "options.max_attempts": ["must be between 1 and 10000000"]
  }
}
```

#### Start Multi-Simulation (MVP2)

```
POST /api/simulations/multi

Request:
{
  "strategy_id": "uuid",
  "count": 5,
  "draw_selection": "random",
  "options": {
    "max_attempts": 1000000,
    "timeout_seconds": 300
  }
}

Success Response (202 Accepted):
{
  "data": {
    "batch_id": "uuid",
    "strategy_id": "uuid",
    "simulations": [
      {
        "id": "uuid-1",
        "target_draw_id": "uuid-a",
        "target_draw_date": "2024-11-08",
        "status": "pending"
      },
      {
        "id": "uuid-2",
        "target_draw_id": "uuid-b",
        "target_draw_date": "2024-11-01",
        "status": "pending"
      }
      /* ... 3 more ... */
    ],
    "total_count": 5
  },
  "message": "Multi-simulation queued for processing"
}

Error Responses:
400 Bad Request
{
  "errors": {
    "count": ["must be between 3 and 10"]
  }
}
```

#### Get Simulation Progress (Long Polling)

```
GET /api/simulations/:id/progress

Success Response (200 OK):
{
  "data": {
    "id": "uuid",
    "status": "running",
    "attempts_count": 50000,
    "duration_seconds": 15.3,
    "started_at": "2025-11-15T10:00:00Z",
    "estimated_completion": "2025-11-15T10:00:45Z"
  }
}

Note: For real-time updates, use Phoenix LiveView WebSocket connection
```

#### Cancel Simulation (MVP2)

```
POST /api/simulations/:id/cancel

Success Response (200 OK):
{
  "data": {
    "id": "uuid",
    "status": "cancelled",
    "attempts_count": 50000,
    "completed_at": "2025-11-15T10:00:20Z"
  }
}

Error Responses:
409 Conflict - Simulation already completed
{
  "error": "Cannot cancel simulation that is already completed"
}
```

---

### 4.5 Rankings

#### Get Strategy Rankings

```
GET /api/rankings/strategies
Query Parameters:
  - scope: user|global (default: user)
  - type: manual|ai_generated|all (default: all)
  - limit: number of results (default: 10, max: 100)

Success Response (200 OK):
{
  "data": [
    {
      "rank": 1,
      "strategy": {
        "id": "uuid",
        "name": "Hot Numbers Focus",
        "type": "manual"
      },
      "performance_score": 85430.5,
      "simulations_count": 25,
      "success_rate": 0.84,
      "avg_duration": 32.1
    },
    {
      "rank": 2,
      "strategy": {
        "id": "uuid",
        "name": "Balanced Mix",
        "type": "ai_generated"
      },
      "performance_score": 125430.5,
      "simulations_count": 15,
      "success_rate": 0.80,
      "avg_duration": 45.2
    }
  ],
  "meta": {
    "total_strategies": 5,
    "with_simulations": 3,
    "calculation_date": "2025-11-15T10:00:00Z"
  }
}
```

#### Get Mix Rankings (MVP2)

```
GET /api/rankings/mixes
Query Parameters:
  - scope: user|global
  - limit: number of results

Success Response (200 OK):
{
  "data": [
    {
      "rank": 1,
      "mix": {
        "id": "uuid",
        "name": "Hot + Cold Hybrid"
      },
      "component_strategies": [
        {"id": "uuid-1", "name": "Hot Focus"},
        {"id": "uuid-2", "name": "Cold Contrarian"}
      ],
      "performance_score": 75430.5,
      "improvement_vs_components": 0.15,
      "simulations_count": 10
    }
  ]
}
```

---

### 4.6 Coupon Generation

#### Generate Coupons

```
POST /api/coupons/generate

Request:
{
  "strategy_id": "uuid",
  "count": 5,
  "game_type": "eurojackpot"
}

Success Response (200 OK):
{
  "data": {
    "coupons": [
      {
        "id": 1,
        "numbers": {
          "main_numbers": [5, 12, 23, 38, 47],
          "euro_numbers": [3, 11]
        }
      },
      {
        "id": 2,
        "numbers": {
          "main_numbers": [2, 15, 27, 34, 49],
          "euro_numbers": [5, 9]
        }
      }
      /* ... 3 more ... */
    ],
    "strategy": {
      "id": "uuid",
      "name": "Hot Numbers Focus"
    },
    "generated_at": "2025-11-15T10:00:00Z"
  }
}

Error Responses:
400 Bad Request
{
  "errors": {
    "count": ["must be between 1 and 10"],
    "strategy_id": ["does not exist or doesn't belong to you"]
  }
}

422 Unprocessable Entity
{
  "error": "Strategy cannot generate unique coupons. Please adjust strategy rules."
}
```

#### Generate from Top Strategies

```
POST /api/coupons/generate/top

Request:
{
  "count": 3,
  "game_type": "eurojackpot"
}

Success Response (200 OK):
{
  "data": {
    "coupons": [ /* generated coupons */ ],
    "strategy": {
      "id": "uuid",
      "name": "Hot Numbers Focus",
      "rank": 1,
      "performance_score": 85430.5
    },
    "generated_at": "2025-11-15T10:00:00Z"
  }
}

Error Responses:
404 Not Found - No strategies with simulations
{
  "error": "You don't have any tested strategies yet. Please run simulations first or create a new strategy.",
  "suggested_action": "create_strategy"
}
```

---

### 4.7 Events & Analytics

#### Log Event

```
POST /api/events

Request:
{
  "event_type": "strategy_created",
  "metadata": {
    "entity_type": "strategy",
    "entity_id": "uuid",
    "strategy_type": "ai_generated",
    "ai_provider": "claude"
  }
}

Success Response (201 Created):
{
  "data": {
    "id": "uuid",
    "event_type": "strategy_created",
    "metadata": { /* echoed metadata */ },
    "inserted_at": "2025-11-15T10:00:00Z"
  }
}
```

#### Get User Analytics

```
GET /api/analytics/me

Success Response (200 OK):
{
  "data": {
    "user_id": "uuid",
    "period": "all_time",
    "stats": {
      "strategies": {
        "total": 5,
        "manual": 2,
        "ai_generated": 3,
        "active": 5
      },
      "simulations": {
        "total": 50,
        "success": 42,
        "timeout": 6,
        "error": 2,
        "success_rate": 0.84
      },
      "performance": {
        "best_strategy": {
          "id": "uuid",
          "name": "Hot Numbers Focus",
          "performance_score": 85430.5
        },
        "avg_attempts": 125430.5,
        "total_simulation_time": 3245.2
      },
      "activity": {
        "coupons_generated": 45,
        "ai_generations": 3,
        "mixes_created": 1,
        "last_active": "2025-11-15T10:00:00Z"
      }
    }
  }
}
```

---

## 5. Validation Rules

### 5.1 Users

- **email:** 
  - Required, valid email format
  - Unique across system
  - Max 255 characters
- **password:**
  - Min 8 characters
  - Must contain at least 1 digit (recommended, not enforced in MVP1)
  - Must match password_confirmation
- **preferences:**
  - Valid JSON object
  - Optional (nullable)

### 5.2 Strategies

- **name:**
  - Required
  - Max 255 characters
  - Non-empty after trimming
- **type:**
  - Required
  - Must be: "manual" or "ai_generated"
- **status:**
  - Must be: "active", "deleted", or "archived"
  - Default: "active"
- **rules:**
  - Required
  - Valid JSON object matching strategy rules schema
  - **main_numbers.weights:** Must sum to 1.0 (±0.001 tolerance)
  - **main_numbers.ratio_even_odd:** Must sum to 5
  - **main_numbers.ratio_low_high:** Must sum to 5
  - **main_numbers.preferred_hot:** Numbers must be in range 1-50
  - **main_numbers.preferred_cold:** Numbers must be in range 1-50
  - **euro_numbers.ratio_even_odd:** Must sum to 2
  - **euro_numbers.preferred:** Numbers must be in range 1-12
  - **euro_numbers.weights:** Must sum to 1.0 (±0.001 tolerance)
- **ai_prompt:**
  - Max 500 characters (for rate limiting and cost control)
  - Required if type is "ai_generated"
  - Nullable if type is "manual"

### 5.3 Draws

- **draw_date:**
  - Required
  - Valid date format (ISO 8601)
  - Unique per game_type
  - Cannot be in the future
- **game_type:**
  - Required
  - Must be: "eurojackpot" (MVP1), "lotto", or "multi_multi"
- **numbers:**
  - Required
  - Valid JSON object
  - **main_numbers:** Array of exactly 5 unique integers between 1-50
  - **euro_numbers:** Array of exactly 2 unique integers between 1-12
  - Numbers must be sorted ascending
- **source:**
  - Must be: "manual", "import", or "admin"
  - Default: "manual"

### 5.4 Simulations

- **strategy_id:**
  - Required
  - Must exist and belong to the requesting user
  - Cannot be null (even if strategy is soft-deleted, ID remains)
- **target_draw_id:**
  - Required
  - Must exist in draws table
- **options.max_attempts:**
  - Must be between 1 and 10,000,000
  - Default: 1,000,000
- **options.timeout_seconds:**
  - Must be between 1 and 600 (10 minutes)
  - Default: 300 (5 minutes)
- **status:**
  - Must be: "pending", "running", "success", "timeout", "error", or "cancelled"
- **attempts_count:**
  - Must be >= 0
- **duration_seconds:**
  - Must be >= 0
- **completed_at:**
  - Must be >= started_at if both exist
- **result:**
  - Required if status is "success"
  - Must be null or valid JSON matching result schema

### 5.5 Coupons (Generation)

- **strategy_id:**
  - Required
  - Must exist and belong to the requesting user
- **count:**
  - Must be between 1 and 10
  - Default: 1
- **game_type:**
  - Required
  - Must match available game types

---

## 6. Business Logic Implementation

### 6.1 Strategy Generation (AI)

**Endpoint:** `POST /api/strategies/generate`

**Process:**
1. Validate user's AI generation rate limit (5/day)
2. Fetch last 32 draws of specified game_type
3. Calculate hot/cold numbers from historical data
4. Build structured prompt including:
   - User's natural language prompt
   - Historical draw data
   - Hot/cold number analysis
   - User's previous strategy performance (if any)
   - System instructions for JSON format
5. Call AI API (OpenAI GPT-4 Turbo or Claude 3.5 Sonnet)
6. Parse and validate JSON response
7. Create strategy record with type "ai_generated"
8. Log event: "ai_request", "ai_success", or "ai_error"
9. Return strategy to user

**Error Handling:**
- AI timeout (30s): Return 503 with fallback suggestion
- Invalid JSON: Return 503 with error details
- Rate limit exceeded: Return 429 with retry_after
- Validation failed: Return 422 with validation errors

### 6.2 Strategy Mixing

**Endpoint:** `POST /api/strategies/mix`

**Process:**
1. Validate all strategy IDs belong to user
2. Fetch all component strategies with performance_scores
3. Analyze rules for conflicts:
   - Incompatible ratio constraints
   - Mutually exclusive preferences
4. If conflicts found: Return 409 with conflict details
5. Build AI prompt to merge strategies:
   - Include all component strategies' rules
   - Weight by performance_score (higher score = higher priority)
   - Request resolution of conflicts
6. Call AI API for merge
7. Parse and validate merged rules
8. Create new strategy with type "ai_generated"
9. Store reference to component strategies in metadata
10. Return new mixed strategy

### 6.3 Simulation Execution

**Endpoint:** `POST /api/simulations`

**Process:**
1. Validate strategy and target draw exist and belong to user
2. Create simulation record with status "pending"
3. Queue async job (Task.async):
   ```elixir
   Task.async(fn ->
     # Initialize state
     state = %{
       attempts: 0,
       start_time: DateTime.utc_now(),
       max_attempts: options.max_attempts,
       timeout: options.timeout_seconds
     }
     
     # Generate and test numbers in loop
     Stream.iterate(0, &(&1 + 1))
     |> Enum.reduce_while(state, fn attempt, state ->
       # Check timeout
       if elapsed_time(state.start_time) > state.timeout do
         {:halt, {:timeout, attempt, :time_limit}}
       end
       
       # Check max attempts
       if attempt >= state.max_attempts do
         {:halt, {:timeout, attempt, :max_attempts}}
       end
       
       # Generate numbers according to strategy rules
       numbers = generate_numbers(strategy.rules)
       
       # Check if matches target (5+2)
       if matches_target?(numbers, target_draw.numbers) do
         {:halt, {:success, attempt, numbers}}
       else
         # Send progress update every 2 seconds
         if rem(attempt, 10000) == 0 do
           send_progress_update(simulation.id, attempt)
         end
         
         {:cont, state}
       end
     end)
   end)
   ```
4. Update simulation record with status "running"
5. When task completes:
   - Update attempts_count, duration_seconds, status, result
   - Set completed_at timestamp
   - Trigger performance_score recalculation for strategy
6. Publish update via Phoenix PubSub for LiveView subscribers

### 6.4 Performance Score Calculation

**Triggered by:** Simulation completion

**Process:**
1. Query all successful simulations for the strategy
2. Calculate median attempts_count using PostgreSQL:
   ```sql
   SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY attempts_count)
   FROM simulations
   WHERE strategy_id = ? AND status = 'success'
   ```
3. Update strategy.performance_score with median value
4. If no successful simulations: Set performance_score to NULL

**Why Median:**
- Less sensitive to outliers than mean
- Better represents "typical" performance
- Used for ranking (lower is better)

### 6.5 Number Generation from Strategy Rules

**Function:** `generate_numbers(rules)`

**Process:**
1. **Main Numbers (5 numbers from 1-50):**
   - Determine even/odd split from ratio_even_odd
   - Determine low/high split from ratio_low_high
   - Build candidate pools:
     - Hot pool: preferred_hot numbers
     - Cold pool: preferred_cold numbers
     - Random pool: all other valid numbers
   - For each of 5 numbers:
     - Randomly select pool based on weights
     - Randomly select number from pool
     - Ensure constraints (even/odd, low/high) are met
     - Remove selected number from pools
   - Sort numbers ascending

2. **Euro Numbers (2 numbers from 1-12):**
   - Determine even/odd split from ratio_even_odd
   - Build candidate pools (hot, random)
   - For each of 2 numbers:
     - Randomly select pool based on weights
     - Randomly select number from pool
     - Ensure even/odd constraint is met
     - Remove selected number from pools
   - Sort numbers ascending

3. **Validation:**
   - Ensure 5 unique main numbers in range 1-50
   - Ensure 2 unique euro numbers in range 1-12
   - Verify constraints are satisfied

### 6.6 Hot/Cold Number Analysis

**Endpoint:** `GET /api/draws/analysis`

**Process:**
1. Query last N draws for specified game_type
2. Count frequency of each number across draws
3. For main numbers (1-50):
   - Calculate frequency and percentage for each
   - Sort by frequency descending
   - Top 10-15 = "hot" numbers
   - Bottom 10-15 = "cold" numbers
4. For euro numbers (1-12):
   - Same process as main numbers
   - Smaller pool so top/bottom 5
5. Return analysis with frequency data

### 6.7 Coupon Generation

**Endpoint:** `POST /api/coupons/generate`

**Process:**
1. Fetch strategy rules
2. Generate N unique number sets using strategy
3. For each generation:
   - Call generate_numbers(rules)
   - Check uniqueness against previously generated
   - Retry up to 100 times if duplicate
   - If can't generate unique: Return 422 error
4. Return array of coupon objects
5. Log event: "coupons_generated"

**Uniqueness Check:**
- Serialize main_numbers + euro_numbers to string
- Store in Set data structure
- Check new generation against Set

### 6.8 Data Isolation (User Scoping)

**Applied to:** All user-owned resources (strategies, simulations, events)

**Implementation Pattern:**
```elixir
# In Phoenix Context
def list_strategies(user) do
  from(s in Strategy, where: s.user_id == ^user.id)
  |> Repo.all()
end

def get_strategy!(user, id) do
  case Repo.get_by(Strategy, id: id, user_id: user.id) do
    nil -> raise Ecto.NoResultsError
    strategy -> strategy
  end
end
```

**Enforcement:**
- Every context function accepts `%User{}` as first parameter
- Queries automatically filtered by user_id
- Attempts to access other users' data return 404
- Enforced at Context layer, not controller
- Test coverage for isolation

---

## 7. Error Handling

### 7.1 HTTP Status Codes

| Code | Meaning | When to Use |
|------|---------|-------------|
| 200 | OK | Successful GET, PATCH, POST (non-creation) |
| 201 | Created | Successful POST (resource created) |
| 202 | Accepted | Async operation queued (simulations) |
| 204 | No Content | Successful DELETE |
| 400 | Bad Request | Validation errors, malformed request |
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Authenticated but not authorized |
| 404 | Not Found | Resource doesn't exist or access denied |
| 409 | Conflict | Business rule conflict (strategy mix) |
| 422 | Unprocessable Entity | Valid request but business logic error |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Unexpected server error |
| 503 | Service Unavailable | External service (AI) unavailable |

### 7.2 Error Response Format

**Standard Error Response:**
```json
{
  "error": "Human-readable error message",
  "errors": {
    "field_name": ["validation error 1", "validation error 2"]
  },
  "meta": {
    "error_code": "VALIDATION_FAILED",
    "request_id": "uuid"
  }
}
```

**Examples:**

**Validation Error (400):**
```json
{
  "errors": {
    "email": ["has already been taken"],
    "password": ["should be at least 8 character(s)"]
  }
}
```

**Business Logic Error (422):**
```json
{
  "error": "Strategy cannot generate valid number sets with these rules",
  "details": "The combination of constraints makes it impossible to generate 5 unique numbers"
}
```

**Rate Limit Error (429):**
```json
{
  "error": "AI generation limit exceeded. You can generate 5 strategies per day.",
  "retry_after": 43200,
  "limit": {
    "max": 5,
    "remaining": 0,
    "reset_at": "2025-11-16T00:00:00Z"
  }
}
```

**Service Unavailable (503):**
```json
{
  "error": "AI service temporarily unavailable",
  "fallback_action": "create_manual",
  "retry_after": 300
}
```

---

## 8. Rate Limiting

### 8.1 Rate Limit Rules

| Endpoint Pattern | Limit | Window | Scope |
|-----------------|-------|--------|-------|
| `POST /api/strategies/generate` | 5 requests | 24 hours | per user |
| `POST /api/strategies/mix` | 10 requests | 24 hours | per user |
| `POST /api/simulations` | 100 requests | 1 hour | per user |
| `POST /api/simulations/multi` | 10 requests | 1 hour | per user |
| `POST /api/coupons/generate` | 100 requests | 1 hour | per user |
| `GET *` | 1000 requests | 1 hour | per user |
| `POST/PATCH/DELETE *` | 200 requests | 1 hour | per user |

### 8.2 Rate Limit Headers

All responses include:
```
X-RateLimit-Limit: 5
X-RateLimit-Remaining: 3
X-RateLimit-Reset: 1637001600
```

### 8.3 Implementation

**Phoenix Plug:**
```elixir
defmodule NumbersEvolutionWeb.RateLimiter do
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(conn, opts) do
    key = rate_limit_key(conn)
    limit = opts[:limit]
    window = opts[:window]
    
    case check_rate_limit(key, limit, window) do
      {:ok, remaining} ->
        conn
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", to_string(remaining))
        
      {:error, retry_after} ->
        conn
        |> put_status(429)
        |> json(%{error: "Rate limit exceeded", retry_after: retry_after})
        |> halt()
    end
  end
end
```

---

## 9. Performance Considerations

### 9.1 Pagination

All list endpoints support pagination:
- Default page size: 20-50 items
- Max page size: 100-200 items
- Cursor-based pagination for large datasets (post-MVP)

### 9.2 Caching

**Cacheable Endpoints:**
- `GET /api/draws` (5 minutes TTL)
- `GET /api/draws/analysis` (1 hour TTL)
- `GET /api/draws/latest` (5 minutes TTL)
- `GET /api/rankings/*` (15 minutes TTL)

**Implementation:** Redis or ETS for caching

### 9.3 Database Optimizations

**Indexes Required:**
- All foreign keys (user_id, strategy_id, target_draw_id)
- Query filters (type, status, game_type)
- Sort fields (performance_score, inserted_at)
- JSONB fields with GIN indexes

**Query Optimization:**
- Use Ecto preloads for associations
- Avoid N+1 queries
- Use database-level aggregations (median, counts)

### 9.4 Background Jobs

**Async Operations:**
- Simulation execution (Task.async)
- Performance score recalculation (Task.async)
- AI API calls (with timeout)

**Job Queue:** Elixir Tasks + GenServer supervision

---

## 10. Versioning

### 10.1 API Versioning Strategy

**Approach:** URL versioning

```
/api/v1/strategies
/api/v2/strategies
```

**Current Version:** v1 (implicit, no version in URL for MVP)

**Future Versioning:**
- Breaking changes: New version (/api/v2/*)
- Non-breaking changes: Same version
- Deprecation notices in headers

### 10.2 Deprecation Policy

**Header:**
```
Deprecation: true
Sunset: Fri, 15 Nov 2026 00:00:00 GMT
Link: </api/v2/strategies>; rel="successor-version"
```

---

## 11. Testing Strategy

### 11.1 Test Coverage Requirements

- All endpoints: Unit tests (ExUnit)
- Business logic: Integration tests
- User isolation: Security tests
- Error cases: Negative tests
- Rate limiting: Load tests

### 11.2 Test Data

**Fixtures:**
- 5 test users
- 50 historical draws
- 10 template strategies
- Sample simulation results

### 11.3 Test Scenarios

**Critical Paths:**
1. User registration → strategy creation → simulation → ranking
2. AI strategy generation → validation → usage in simulation
3. Strategy mixing → conflict detection → resolution
4. Multi-simulation → parallel execution → aggregated results

---

## 12. Documentation

### 12.1 OpenAPI/Swagger

Generate OpenAPI 3.0 specification for interactive documentation.

**Tools:**
- `open_api_spex` (Elixir library)
- Swagger UI for interactive docs

**Hosted at:** `/api/docs`

### 12.2 Code Examples

Provide examples for:
- Authentication flow
- Strategy CRUD operations
- Running simulations
- Generating coupons

**Languages:**
- cURL
- JavaScript (fetch)
- Python (requests)
- Elixir (HTTPoison)

---

## 13. Security Considerations

### 13.1 Input Validation

- Sanitize all user inputs
- Validate JSON schema for JSONB fields
- Max length for text fields (prevent DoS)
- Whitelist allowed values for enums

### 13.2 SQL Injection Prevention

- Use Ecto parameterized queries exclusively
- Never use raw SQL with user input
- Validate IDs are valid UUIDs

### 13.3 XSS Prevention

- Phoenix.HTML auto-escapes output
- Validate and sanitize JSONB content
- Set Content-Security-Policy headers

### 13.4 CSRF Protection

- Enabled by default for Phoenix forms
- API endpoints exempt (stateless token auth)
- Double-submit cookie pattern for browser clients

### 13.5 Secrets Management

- API keys in environment variables
- Never log sensitive data
- Use Fly.io secrets for production
- Rotate tokens periodically

### 13.6 AI Prompt Injection

- Max prompt length (500 chars)
- Sanitize user prompts
- System prompt guards against injection
- Rate limiting per user

---

## 14. Monitoring & Observability

### 14.1 Logging

**Log Levels:**
- ERROR: Unexpected errors, AI failures
- WARN: Rate limit exceeded, validation failures
- INFO: Request/response, simulation starts/ends
- DEBUG: Detailed execution traces

**Structured Logging:**
```elixir
Logger.info("Simulation completed",
  simulation_id: id,
  strategy_id: strategy_id,
  attempts: attempts,
  duration: duration,
  status: status
)
```

### 14.2 Metrics

**Key Metrics:**
- Request rate per endpoint
- Response time percentiles (p50, p95, p99)
- Error rate by status code
- AI API latency and error rate
- Simulation throughput
- Database query performance

**Tools:**
- Telemetry (Elixir)
- Phoenix LiveDashboard
- Prometheus + Grafana (post-MVP)

### 14.3 Alerting

**Alert Conditions:**
- Error rate > 5% for 5 minutes
- AI API error rate > 20%
- Database connection pool exhausted
- Response time p95 > 2 seconds
- Simulation queue depth > 100

---

## 15. API Clients

### 15.1 Official Clients

**Phoenix LiveView (Primary):**
- Built-in WebSocket communication
- Auto-generated forms with Phoenix.Component
- Real-time updates via PubSub

**Future:**
- JavaScript SDK (for external integrations)
- Mobile SDKs (iOS/Android)

### 15.2 Example Integration

**JavaScript (Browser):**
```javascript
// Authenticate
const response = await fetch('/api/auth/token', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    email: 'user@example.com',
    password: 'password123'
  })
});
const { token } = await response.json();

// Create strategy
const strategy = await fetch('/api/strategies', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({
    name: 'My Strategy',
    type: 'manual',
    rules: { /* ... */ }
  })
});

// Start simulation
const simulation = await fetch('/api/simulations', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({
    strategy_id: strategy.id,
    target_draw_id: 'uuid'
  })
});
```

---

## 16. Migration & Backward Compatibility

### 16.1 Database Migrations

All schema changes must:
- Be backward compatible (additive only)
- Include rollback scripts
- Be tested on production-like data

### 16.2 API Changes

**Non-Breaking Changes (allowed in same version):**
- Adding new optional fields
- Adding new endpoints
- Adding new query parameters
- Expanding enum values

**Breaking Changes (require new version):**
- Removing fields
- Changing field types
- Renaming fields
- Removing endpoints
- Changing validation rules (more restrictive)

---

## 17. Appendix

### 17.1 Example Strategy Rules Schema

```json
{
  "main_numbers": {
    "ratio_even_odd": [2, 3],
    "ratio_low_high": [3, 2],
    "preferred_hot": [7, 23, 34],
    "preferred_cold": [1, 50],
    "weights": {
      "hot": 0.4,
      "cold": 0.2,
      "random": 0.4
    }
  },
  "euro_numbers": {
    "ratio_even_odd": [1, 1],
    "preferred": [3, 9],
    "weights": {
      "hot": 0.5,
      "random": 0.5
    }
  }
}
```

### 17.2 Example Simulation Result Schema

**Success:**
```json
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

**Timeout:**
```json
{
  "reason": "timeout",
  "limit_reached": "max_attempts",
  "attempts_count": 1000000,
  "error_message": null
}
```

### 17.3 AI Prompt Template

```
You are a lottery strategy expert. Generate a strategy for Eurojackpot based on:

USER REQUEST: "Create a balanced strategy focusing on recent hot numbers"

HISTORICAL DATA (last 32 draws):
- Hot main numbers: 7 (12x), 23 (11x), 34 (10x)
- Cold main numbers: 1 (2x), 50 (3x)
- Hot euro numbers: 3 (15x), 9 (13x)
- Cold euro numbers: 1 (1x)

USER'S BEST PERFORMING STRATEGY:
- Name: "Pure Random"
- Performance: 250,000 attempts median

Generate a strategy in this JSON format:
{
  "strategy_name": "string",
  "description": "string",
  "reasoning": "string",
  "game_type": "eurojackpot",
  "rules": { /* rules schema */ }
}

Ensure weights sum to 1.0 and ratios are valid.
```

---

## 18. Future Enhancements

### 18.1 Planned Features (Post-MVP)

1. **GraphQL API** (alternative to REST)
2. **Webhook subscriptions** (simulation completed events)
3. **Batch operations** (bulk strategy import/export)
4. **Advanced analytics** (trends, patterns, ML insights)
5. **Social features** (public strategy sharing)
6. **Additional games** (Lotto, Multi Multi)

### 18.2 API Roadmap

**Q1 2026:**
- v1 stable release
- OpenAPI documentation
- JavaScript SDK

**Q2 2026:**
- GraphQL endpoint
- Webhook system
- Mobile APIs (iOS/Android optimization)

**Q3 2026:**
- v2 with breaking changes (if needed)
- Advanced analytics endpoints
- Machine learning integration

---

**Document Status:** Draft for Review  
**Last Updated:** November 15, 2025  
**Next Review:** Pre-implementation (Week 0-1)

