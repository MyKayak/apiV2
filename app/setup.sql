
DROP VIEW IF EXISTS titles_view;
DROP VIEW IF EXISTS athlete_time_progression_view;
DROP VIEW IF EXISTS personal_records_view;
DROP VIEW IF EXISTS athlete_rankings_view;
DROP VIEW IF EXISTS medal_table_view;

DROP FUNCTION IF EXISTS get_athlete_current_team(INT);

DROP TABLE IF EXISTS followed_teams CASCADE;
DROP TABLE IF EXISTS followed_athletes CASCADE;
DROP TABLE IF EXISTS tokens CASCADE;
DROP TABLE IF EXISTS outcomes CASCADE;
DROP TABLE IF EXISTS performances_athletes CASCADE;
DROP TABLE IF EXISTS performances CASCADE;
DROP TABLE IF EXISTS heats CASCADE;
DROP TABLE IF EXISTS races CASCADE;
DROP TABLE IF EXISTS meets CASCADE;
DROP TABLE IF EXISTS admins CASCADE;
DROP TABLE IF EXISTS athletes CASCADE;
DROP TABLE IF EXISTS teams CASCADE;

CREATE TABLE teams (
    team_id CHAR(5) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    logo TEXT,
    performance_count INT DEFAULT 0
);

CREATE TABLE athletes (
    athlete_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    surname VARCHAR(255) NOT NULL,
    birth_date DATE,
    CONSTRAINT uq_athlete UNIQUE (name, surname, birth_date)
);
CREATE INDEX idx_athletes_birth_date ON athletes (birth_date);
CREATE INDEX idx_athletes_name ON athletes (name, surname);

CREATE TABLE admins (
    admin_id SERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL
);

CREATE TABLE meets (
    meet_id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    location VARCHAR(255),
    date DATE,
    is_championship BOOLEAN DEFAULT FALSE
);
CREATE INDEX idx_meets_date ON meets (date);
CREATE INDEX idx_meets_championship ON meets (is_championship);

CREATE TABLE races (
    race_id SERIAL PRIMARY KEY,
    race_code VARCHAR(255) NOT NULL,
    meet_id VARCHAR(255) NOT NULL,
    distance INT NOT NULL,
    division CHAR(3) NOT NULL,
    category CHAR(1) NOT NULL,
    boat CHAR(2) NOT NULL,
    level CHAR(2) NOT NULL,
    start_time TIMESTAMP,
    FOREIGN KEY (meet_id) REFERENCES meets(meet_id) ON DELETE CASCADE,
    CONSTRAINT uq_races_code_meet UNIQUE (race_code, meet_id)
);
CREATE INDEX idx_races_meet_id ON races (meet_id);

CREATE TABLE heats (
    heat_id SERIAL PRIMARY KEY,
    heat_index INT NOT NULL,
    race_id INT NOT NULL,
    start_time TIMESTAMP,
    is_result BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (race_id) REFERENCES races(race_id) ON DELETE CASCADE,
    CONSTRAINT uq_heat UNIQUE (heat_index, race_id)
);
CREATE INDEX idx_heats_race_id ON heats (race_id);

CREATE TABLE performances (
    performance_id SERIAL PRIMARY KEY,
    heat_id INT NOT NULL,
    team_id CHAR(5),
    lane INT,
    placement INT,
    time_ms INT NULL,
    status VARCHAR(3) NULL,
    points INT DEFAULT 0,
    FOREIGN KEY (heat_id) REFERENCES heats(heat_id) ON DELETE CASCADE
);
CREATE INDEX idx_performances_heat_id ON performances (heat_id);
CREATE INDEX idx_performances_team_id ON performances (team_id);

CREATE TABLE outcomes (
    performance_id INT,
    outcome VARCHAR(255),
    FOREIGN KEY (performance_id) REFERENCES performances(performance_id) ON DELETE CASCADE,
    UNIQUE (performance_id, outcome)
);

CREATE TABLE performances_athletes (
    performance_id INT NOT NULL,
    athlete_id INT NOT NULL,
    PRIMARY KEY (performance_id, athlete_id),
    FOREIGN KEY (performance_id) REFERENCES performances(performance_id) ON DELETE CASCADE,
    FOREIGN KEY (athlete_id) REFERENCES athletes(athlete_id) ON DELETE CASCADE
);

CREATE TABLE tokens (
    token_id SERIAL PRIMARY KEY,
    admin_id INT NOT NULL,
    token CHAR(64) NOT NULL,
    expiration_date DATE NOT NULL,
    FOREIGN KEY (admin_id) REFERENCES admins(admin_id) ON DELETE CASCADE
);

CREATE TABLE followed_athletes (
    admin_id INT NOT NULL,
    athlete_id INT NOT NULL,
    PRIMARY KEY (admin_id, athlete_id),
    FOREIGN KEY (admin_id) REFERENCES admins(admin_id) ON DELETE CASCADE,
    FOREIGN KEY (athlete_id) REFERENCES athletes(athlete_id) ON DELETE CASCADE
);

CREATE TABLE followed_teams (
    admin_id INT NOT NULL,
    team_id CHAR(5) NOT NULL,
    PRIMARY KEY (admin_id, team_id),
    FOREIGN KEY (admin_id) REFERENCES admins(admin_id) ON DELETE CASCADE,
    FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE CASCADE
);

CREATE OR REPLACE VIEW medal_table_view AS
SELECT
    meets.meet_id,
    meets.date,
    meets.is_championship,
    team_id,
    teams.name AS team_name,
    SUM(CASE WHEN placement = 1 THEN 1 ELSE 0 END) AS gold,
    SUM(CASE WHEN placement = 2 THEN 1 ELSE 0 END) AS silver,
    SUM(CASE WHEN placement = 3 THEN 1 ELSE 0 END) AS bronze,
    COUNT(*) AS total_medals
FROM meets
JOIN races ON meets.meet_id = races.meet_id
JOIN heats ON races.race_id = heats.race_id
JOIN performances USING (heat_id)
JOIN teams USING (team_id)
WHERE races.level IN ('SR', 'DF', 'FA')
  AND placement BETWEEN 1 AND 3
  AND status IS NULL
GROUP BY meets.meet_id, team_id, teams.name;

CREATE OR REPLACE VIEW athlete_rankings_view AS
SELECT
    athletes.athlete_id,
    athletes.name,
    athletes.surname,
    athletes.birth_date,
    races.distance,
    races.boat,
    races.category,
    races.division,
    performances.time_ms,
    meets.date
FROM athletes
INNER JOIN performances_athletes USING (athlete_id)
INNER JOIN performances USING (performance_id)
INNER JOIN heats USING (heat_id)
INNER JOIN races USING (race_id)
INNER JOIN meets USING (meet_id)
WHERE races.boat IN ('K1', 'C1')
  AND performances.time_ms IS NOT NULL
  AND performances.status IS NULL
  AND performances.time_ms >= 25000
ORDER BY athletes.athlete_id, races.distance, races.boat, races.category, races.division, meets.date DESC;

CREATE OR REPLACE VIEW personal_records_view AS (
    SELECT athlete_id, boat, distance, category, MIN(time_ms) AS time 
    FROM athletes
    INNER JOIN performances_athletes USING (athlete_id)
    INNER JOIN performances USING (performance_id)
    INNER JOIN heats USING (heat_id)
    INNER JOIN races USING (race_id)
    GROUP BY boat, distance, category, athlete_id
);

CREATE OR REPLACE VIEW athlete_time_progression_view AS
SELECT 
    performances_athletes.athlete_id,
    races.distance,
    races.boat,
    races.category,
    performances.time_ms,
    meets.date
FROM performances_athletes
INNER JOIN performances USING (performance_id)
INNER JOIN heats USING (heat_id)
INNER JOIN races USING (race_id)
INNER JOIN meets USING (meet_id)
WHERE performances.time_ms IS NOT NULL
ORDER BY performances_athletes.athlete_id, races.distance, races.boat, races.category, meets.date;

CREATE OR REPLACE FUNCTION get_athlete_current_team(p_athlete_id INT)
RETURNS TABLE (
    team_id CHAR(5),
    team_name VARCHAR(255),
    logo TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT t.team_id, t.name AS team_name, t.logo
    FROM performances_athletes pa
    JOIN performances p USING (performance_id)
    JOIN heats h USING (heat_id)
    JOIN races r USING (race_id)
    JOIN meets m USING (meet_id)
    JOIN teams t USING (team_id)
    WHERE pa.athlete_id = p_athlete_id
    ORDER BY m.date DESC, r.race_id DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW titles_view AS
SELECT 
    athlete_id, 
    performance_id, 
    team_id, 
    time_ms, 
    athletes.name, 
    surname, 
    heats.start_time, 
    distance, 
    division, 
    category, 
    boat, 
    location 
FROM performances
INNER JOIN performances_athletes USING (performance_id)
INNER JOIN athletes USING (athlete_id)
INNER JOIN heats USING (heat_id)
INNER JOIN races USING (race_id)
INNER JOIN meets USING (meet_id)
WHERE is_championship = true
AND time_ms > 0
AND placement = 1
AND (level = 'DF' OR level = 'FA')
ORDER BY heats.start_time DESC;
