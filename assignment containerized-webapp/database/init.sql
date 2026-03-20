CREATE TABLE IF NOT EXISTS students(
 id SERIAL PRIMARY KEY,
 name VARCHAR(100),
 roll_number VARCHAR(20),
 department VARCHAR(50),
 year INT
);