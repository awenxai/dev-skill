# Python Language Guide

Reference for Phase 5 of the code review workflow. Load this file when the stack fingerprint is `pyproject.toml`, `requirements.txt`, or `setup.py`.

---

## Type Hints

All public functions and methods must have type hints on parameters and return values.

### Rules
- Use `from __future__ import annotations` for forward references in older Python versions.
- Use `Optional[T]` (or `T | None` in Python 3.10+) for nullable values — never leave them implicit.
- Avoid `Any` — use `Union`, `TypeVar`, or `Protocol` instead.
- Run `mypy` or `pyright` in strict mode; flag any `# type: ignore` that isn't accompanied by a comment explaining why.

```python
# VIOLATION — no type hints on public function
def create_order(user_id, items, discount=None):
    ...

# CORRECT
from typing import Optional
from decimal import Decimal

def create_order(
    user_id: str,
    items: list[OrderItem],
    discount: Optional[Decimal] = None,
) -> Order:
    ...
```

```python
# VIOLATION — Any kills type safety
from typing import Any
def process(data: Any) -> Any: ...

# CORRECT — use Protocol or TypeVar
from typing import Protocol

class Processable(Protocol):
    def validate(self) -> bool: ...

def process(data: Processable) -> ProcessResult: ...
```

**Severity:** Missing type hints on public API = 🟡 `[P2]`. Use of `Any` in security-sensitive code = 🟠 `[P1]`.

---

## Async Safety

### Rules
- Never call blocking I/O inside an `async` function without `await` or offloading to a thread pool.
- Use `asyncio.gather()` for concurrent async tasks; use `asyncio.wait_for()` to apply timeouts.
- Never use `time.sleep()` in async code — use `await asyncio.sleep()`.
- Use `httpx.AsyncClient` instead of `requests` in async code.

```python
# VIOLATION — blocking I/O in async function stalls the event loop
async def get_user(user_id: str) -> User:
    response = requests.get(f"{API_URL}/users/{user_id}")  # BLOCKING
    return User(**response.json())

# CORRECT
import httpx

async def get_user(user_id: str) -> User:
    async with httpx.AsyncClient() as client:
        response = await client.get(f"{API_URL}/users/{user_id}")
        response.raise_for_status()
        return User(**response.json())
```

```python
# VIOLATION — blocking DB call in async path (Django ORM / psycopg2)
async def handle_request(request):
    user = User.objects.get(id=request.user_id)  # sync ORM in async view

# CORRECT (Django 4.1+ async ORM)
async def handle_request(request):
    user = await User.objects.aget(id=request.user_id)

# CORRECT (sync wrapped in executor)
import asyncio
user = await asyncio.get_event_loop().run_in_executor(None, lambda: User.objects.get(id=user_id))
```

**Severity:** Blocking call in async function = 🟠 `[P1]`.

---

## ORM: N+1 Query Detection

N+1 queries are one of the most common performance killers in Python web apps.

### Detection signals
- A loop that calls `.relationship`, `.objects.get()`, or `.filter()` inside each iteration
- `for order in orders: print(order.user.name)` — fetches user for each order

### SQLAlchemy
```python
# VIOLATION — N+1: each order triggers a separate query for user
orders = session.query(Order).all()
for order in orders:
    print(order.user.name)  # SELECT user WHERE id = ? — once per order

# CORRECT — eager load with joinedload
from sqlalchemy.orm import joinedload
orders = session.query(Order).options(joinedload(Order.user)).all()
for order in orders:
    print(order.user.name)  # no extra queries
```

### Django ORM
```python
# VIOLATION — N+1
orders = Order.objects.all()
for order in orders:
    print(order.customer.name)  # extra query per order

# CORRECT
orders = Order.objects.select_related('customer').all()
# For many-to-many or reverse FK:
orders = Order.objects.prefetch_related('items').all()
```

**Severity:** N+1 on large datasets = 🟠 `[P1]`. On small/bounded datasets = 🟡 `[P2]`.

---

## Security

### subprocess safety
```python
# VIOLATION — shell=True allows injection
subprocess.run(f"ls {directory}", shell=True)
os.system(f"convert {user_input} output.png")

# CORRECT — args list, no shell
subprocess.run(["ls", directory], check=True)
subprocess.run(["convert", user_input, "output.png"], check=True, timeout=30)
```

### pickle dangers
```python
# NEVER deserialize pickle from untrusted sources
data = pickle.loads(request.data)  # CRITICAL — arbitrary code execution

# Use JSON + Pydantic for untrusted data
from pydantic import BaseModel
class Payload(BaseModel):
    action: str
    data: dict
payload = Payload.model_validate_json(request.data)
```

### eval / exec
```python
# NEVER
result = eval(user_expression)
exec(user_code)

# If you need expression evaluation: use ast.literal_eval for safe literal eval
import ast
value = ast.literal_eval(user_string)  # safe — only literals, no function calls
```

### yaml.load
```python
# VIOLATION — yaml.load executes arbitrary Python with !!python/object tags
config = yaml.load(user_input)

# CORRECT
config = yaml.safe_load(user_input)
```

**Severity:** pickle/eval/exec with untrusted input = 🔴 `[P0]`. subprocess with shell=True = 🔴 `[P0]`.

---

## Pydantic Validation

When using Pydantic (FastAPI, modern Django setups):

- All incoming request data must be modeled as a Pydantic `BaseModel` — no raw `dict` access.
- Use `model_validate` (Pydantic v2) / `parse_obj` (Pydantic v1) — never construct models with `**dict` from untrusted sources without validation.
- Use `@field_validator` and `@model_validator` for custom validation logic.
- Set `model_config = ConfigDict(extra='forbid')` to reject unexpected fields from external input.

```python
from pydantic import BaseModel, field_validator, ConfigDict
from decimal import Decimal

class CreateOrderRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    user_id: str
    items: list[OrderItemRequest]
    discount_code: str | None = None

    @field_validator('user_id')
    @classmethod
    def user_id_must_be_uuid(cls, v: str) -> str:
        try:
            uuid.UUID(v)
        except ValueError:
            raise ValueError('user_id must be a valid UUID')
        return v
```

**Severity:** Raw `dict` from request without validation = 🟠 `[P1]`.

---

## Testing

### pytest conventions
- Test files: `test_*.py` or `*_test.py`
- Fixtures: `conftest.py` at the appropriate directory level
- Use `pytest.mark.parametrize` for table-driven tests

```python
import pytest

@pytest.mark.parametrize("email,expected_valid", [
    ("user@example.com", True),
    ("not-an-email", False),
    ("", False),
    ("user@", False),
])
def test_validate_email(email: str, expected_valid: bool):
    result = validate_email(email)
    assert result == expected_valid
```

### Mocking
- Use `unittest.mock.patch` or `pytest-mock`'s `mocker` fixture.
- Mock at the boundary (the import in the module under test), not at the source.

```python
# CORRECT — mock where it's used, not where it's defined
def test_send_email(mocker):
    mock_send = mocker.patch('app.services.email_service.smtp_client.send')
    service.notify_user(user_id='123')
    mock_send.assert_called_once()
```

### Exception testing
```python
# Test that the right exception is raised with the right message
def test_create_order_fails_for_unknown_user():
    with pytest.raises(UserNotFoundError, match="user_id='nonexistent'"):
        service.create_order(user_id='nonexistent', items=[])
```

**Severity:** Missing error path tests = 🟡 `[P2]`. No tests for new logic = 🟠 `[P1]`.

---

## Common Python Anti-Patterns

| Anti-pattern | Correct approach | Severity |
|-------------|-----------------|---------|
| Bare `except:` or `except Exception: pass` | Catch specific exceptions, log | 🟡 P2 |
| Mutable default arguments `def fn(items=[])` | Use `None` + `if items is None: items = []` | 🟠 P1 |
| `pickle` from untrusted input | JSON + Pydantic | 🔴 P0 |
| `shell=True` with user input | Args list form | 🔴 P0 |
| N+1 ORM queries | `select_related` / `joinedload` | 🟠 P1 |
| Missing type hints on public API | Add type hints | 🟡 P2 |
| `time.sleep()` in async function | `await asyncio.sleep()` | 🟠 P1 |
| Blocking HTTP in async (`requests`) | `httpx.AsyncClient` | 🟠 P1 |
| `global` state mutation | Dependency injection | 🟡 P2 |
| `print()` for logging | Structured logger | 🟡 P2 |
