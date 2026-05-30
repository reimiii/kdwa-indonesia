PRAGMA foreign_keys = OFF;
drop index if exists idx_regions_parent_code;
drop index if exists idx_regions_level;
drop index if exists idx_regions_name;
drop index if exists idx_regions_level_name;
drop table if exists regions;
CREATE TABLE regions (
    id integer primary key autoincrement,
    code text not null unique,
    name text not null,
    breadcrumb text,
    level integer not null,
        -- 1 = province,
        -- 2 = regency,
        -- 3 = city,
        -- 4 = district,
        -- 5 = urban village,
        -- 6 = village,
        -- 7 = indigenous village
    parent_code text,
    foreign key (parent_code) references regions(code)
);
CREATE INDEX idx_regions_parent_code on regions(parent_code);
CREATE INDEX idx_regions_level on regions(level);
CREATE INDEX idx_regions_name on regions(name);
CREATE INDEX idx_regions_level_name on regions(level, name);
PRAGMA foreign_keys = ON;
