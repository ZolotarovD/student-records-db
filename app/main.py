import os
import asyncio
from typing import Optional, Any, Dict, List

import asyncpg
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "student_records")
DB_USER = os.getenv("DB_USER", "sr_admin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "sr_pass")

app = FastAPI(title="Student Records API", version="1.0.0")
pool: Optional[asyncpg.Pool] = None


async def get_pool() -> asyncpg.Pool:
    global pool
    if pool is None:
        raise RuntimeError("DB pool not initialized")
    return pool


async def init_pool_with_retry(retries: int = 30, delay_sec: float = 1.0) -> asyncpg.Pool:
    last_exc = None
    for _ in range(retries):
        try:
            p = await asyncpg.create_pool(
                host=DB_HOST,
                port=DB_PORT,
                user=DB_USER,
                password=DB_PASSWORD,
                database=DB_NAME,
                min_size=1,
                max_size=5,
            )
            async with p.acquire() as conn:
                await conn.execute("SELECT 1;")
            return p
        except Exception as exc:
            last_exc = exc
            await asyncio.sleep(delay_sec)
    raise last_exc  # type: ignore


@app.on_event("startup")
async def startup_event() -> None:
    global pool
    pool = await init_pool_with_retry()


@app.on_event("shutdown")
async def shutdown_event() -> None:
    global pool
    if pool is not None:
        await pool.close()
        pool = None


@app.get("/health")
async def health() -> Dict[str, str]:
    p = await get_pool()
    async with p.acquire() as conn:
        await conn.execute("SELECT 1;")
    return {"status": "ok"}


class GroupCreate(BaseModel):
    program_id: int = Field(..., ge=1)
    name: str = Field(..., min_length=1, max_length=50)
    year_start: int = Field(..., ge=1990, le=2100)
    curator_instructor_id: Optional[int] = Field(default=None, ge=1)


@app.get("/groups")
async def list_groups() -> List[Dict[str, Any]]:
    p = await get_pool()
    async with p.acquire() as conn:
        rows = await conn.fetch("""
            SELECT g.id, g.name, g.year_start,
                   p.name AS program_name, p.degree_level,
                   d.name AS department_name
            FROM academic_group g
            JOIN program p ON p.id = g.program_id
            JOIN department d ON d.id = p.department_id
            ORDER BY g.name;
        """)
    return [dict(r) for r in rows]


@app.post("/groups", status_code=201)
async def create_group(payload: GroupCreate) -> Dict[str, Any]:
    p = await get_pool()
    async with p.acquire() as conn:
        try:
            row = await conn.fetchrow("""
                INSERT INTO academic_group(program_id, name, year_start, curator_instructor_id)
                VALUES ($1, $2, $3, $4)
                RETURNING id, name, year_start;
            """, payload.program_id, payload.name, payload.year_start, payload.curator_instructor_id)
            await conn.execute("""
                INSERT INTO audit_log(user_id, action, entity, entity_id, details)
                VALUES (NULL, 'create', 'academic_group', $1, jsonb_build_object('name',$2));
            """, row["id"], row["name"])
        except asyncpg.UniqueViolationError:
            raise HTTPException(status_code=409, detail="Group name already exists")
        except asyncpg.ForeignKeyViolationError:
            raise HTTPException(status_code=400, detail="Invalid program_id or curator_instructor_id")
    return dict(row)


class StudentCreate(BaseModel):
    group_id: int = Field(..., ge=1)
    first_name: str = Field(..., min_length=1, max_length=100)
    last_name: str = Field(..., min_length=1, max_length=100)
    email: str = Field(..., min_length=5, max_length=200)
    enrollment_year: int = Field(..., ge=1990, le=2100)
    status: str = Field(default="active")


@app.get("/students")
async def list_students() -> List[Dict[str, Any]]:
    p = await get_pool()
    async with p.acquire() as conn:
        rows = await conn.fetch("""
            SELECT s.id, s.first_name, s.last_name, s.email, s.enrollment_year, s.status,
                   g.name AS group_name
            FROM student s
            JOIN academic_group g ON g.id = s.group_id
            ORDER BY s.last_name, s.first_name;
        """)
    return [dict(r) for r in rows]


@app.post("/students", status_code=201)
async def create_student(payload: StudentCreate) -> Dict[str, Any]:
    if payload.status not in ("active", "academic_leave", "graduated", "expelled"):
        raise HTTPException(status_code=400, detail="Invalid status")
    p = await get_pool()
    async with p.acquire() as conn:
        try:
            row = await conn.fetchrow("""
                INSERT INTO student(group_id, first_name, last_name, email, enrollment_year, status)
                VALUES ($1,$2,$3,$4,$5,$6)
                RETURNING id, first_name, last_name, email;
            """, payload.group_id, payload.first_name, payload.last_name,
                 payload.email, payload.enrollment_year, payload.status)
            await conn.execute("""
                INSERT INTO audit_log(user_id, action, entity, entity_id, details)
                VALUES (NULL, 'create', 'student', $1, jsonb_build_object('email',$2));
            """, row["id"], row["email"])
        except asyncpg.UniqueViolationError:
            raise HTTPException(status_code=409, detail="Student email already exists")
        except asyncpg.ForeignKeyViolationError:
            raise HTTPException(status_code=400, detail="Invalid group_id")
    return dict(row)


class EnrollCreate(BaseModel):
    student_id: int = Field(..., ge=1)
    offering_id: int = Field(..., ge=1)


@app.post("/enroll", status_code=201)
async def enroll_student(payload: EnrollCreate) -> Dict[str, Any]:
    p = await get_pool()
    async with p.acquire() as conn:
        try:
            row = await conn.fetchrow("""
                INSERT INTO enrollment(offering_id, student_id)
                VALUES ($1,$2)
                RETURNING id, offering_id, student_id, enrolled_at;
            """, payload.offering_id, payload.student_id)
            await conn.execute("""
                INSERT INTO audit_log(user_id, action, entity, entity_id, details)
                VALUES (NULL, 'create', 'enrollment', $1, jsonb_build_object('student_id',$2,'offering_id',$3));
            """, row["id"], payload.student_id, payload.offering_id)
        except asyncpg.UniqueViolationError:
            raise HTTPException(status_code=409, detail="Already enrolled")
        except asyncpg.ForeignKeyViolationError:
            raise HTTPException(status_code=400, detail="Invalid student_id or offering_id")
    return dict(row)


class GradeUpsert(BaseModel):
    enrollment_id: int = Field(..., ge=1)
    component_id: int = Field(..., ge=1)
    points: float = Field(..., ge=0)


@app.post("/grade", status_code=201)
async def upsert_grade(payload: GradeUpsert) -> Dict[str, Any]:
    p = await get_pool()
    async with p.acquire() as conn:
        try:
            row = await conn.fetchrow("""
                INSERT INTO grade(enrollment_id, component_id, points)
                VALUES ($1,$2,$3)
                ON CONFLICT (enrollment_id, component_id)
                DO UPDATE SET points = EXCLUDED.points, graded_at = NOW()
                RETURNING id, enrollment_id, component_id, points, graded_at;
            """, payload.enrollment_id, payload.component_id, payload.points)
            await conn.execute("""
                INSERT INTO audit_log(user_id, action, entity, entity_id, details)
                VALUES (NULL, 'upsert', 'grade', $1, jsonb_build_object('enrollment_id',$2,'component_id',$3,'points',$4));
            """, row["id"], payload.enrollment_id, payload.component_id, payload.points)
        except asyncpg.ForeignKeyViolationError:
            raise HTTPException(status_code=400, detail="Invalid enrollment_id or component_id")
    return dict(row)


@app.get("/report/group/{group_name}/semester/{year}/{term}")
async def report_group_semester(group_name: str, year: int, term: str) -> List[Dict[str, Any]]:
    if term not in ("spring", "fall"):
        raise HTTPException(status_code=400, detail="term must be spring or fall")

    p = await get_pool()
    async with p.acquire() as conn:
        rows = await conn.fetch("""
            SELECT
              g.name AS group_name,
              s.id AS student_id,
              s.last_name,
              s.first_name,
              c.code AS course_code,
              c.name AS course_name,
              SUM(gr.points * ac.weight) AS weighted_points
            FROM academic_group g
            JOIN student s ON s.group_id = g.id
            JOIN course_offering o ON o.group_id = g.id
            JOIN semester sem ON sem.id = o.semester_id
            JOIN course c ON c.id = o.course_id
            LEFT JOIN enrollment e ON e.offering_id = o.id AND e.student_id = s.id
            LEFT JOIN grade gr ON gr.enrollment_id = e.id
            LEFT JOIN assessment_component ac ON ac.id = gr.component_id
            WHERE g.name = $1 AND sem.year = $2 AND sem.term = $3
            GROUP BY g.name, s.id, s.last_name, s.first_name, c.code, c.name
            ORDER BY s.last_name, s.first_name, c.code;
        """, group_name, year, term)

    return [dict(r) for r in rows]
