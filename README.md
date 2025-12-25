# Student Records DB (мінімальний курсовий проєкт)

Це **мінімальна робоча програма** під тему:
**"Проектування бази даних для управління студентськими записами"**.

✅ Є **10+ таблиць** (навіть 17)  
✅ Є **Docker** (PostgreSQL + API)  
✅ Є **тестові дані** (seed)  
✅ Є **проста програма (API)** для демонстрації CRUD/операцій

---

## 1) Запуск (тільки Ctrl+C / Ctrl+V)

### Вимоги на ПК:
- Docker Desktop (або Docker Engine + docker compose)

### Команди:
```bash
# 1) В каталозі проєкту
docker compose up --build
```

Після старту:
- DB: `localhost:5432`
- API: `http://localhost:8000`

---

## 2) Перевірка, що працює (готові команди)

### Health:
```bash
curl http://localhost:8000/health
```

### Список груп:
```bash
curl http://localhost:8000/groups
```

### Список студентів:
```bash
curl http://localhost:8000/students
```

### Додати студента (Windows CMD):
```bash
curl -X POST http://localhost:8000/students ^
  -H "Content-Type: application/json" ^
  -d "{"group_id":1,"first_name":"Test","last_name":"Student","email":"test.student@uni.test","enrollment_year":2025,"status":"active"}"
```

### Записати оцінку (upsert) (Windows CMD):
```bash
curl -X POST http://localhost:8000/grade ^
  -H "Content-Type: application/json" ^
  -d "{"enrollment_id":1,"component_id":1,"points":58}"
```

### Звіт по групі (SE-21) за семестр:
```bash
curl http://localhost:8000/report/group/SE-21/semester/2025/fall
```

---

## 3) Git (мінімум)

```bash
git init
git add .
git commit -m "Initial version: DB + API + Docker"
```

---

## 4) Де що лежить
- `db/init/01_schema.sql` – створення таблиць (DDL)
- `db/init/02_seed.sql` – тестові дані (DML)
- `docker-compose.yml` – піднімає Postgres та API
- `app/main.py` – код програми (FastAPI)
