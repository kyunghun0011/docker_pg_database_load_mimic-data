#!/bin/bash

echo 'CREATING MIMIC IV... '

# this flag allows us to initialize the docker repo without building the data
if [ $BUILD_MIMIC -eq 1 ]
then
echo "running create mimic user"

pg_ctl stop

pg_ctl -D "$PGDATA" \
	-o "-c listen_addresses='' -c checkpoint_timeout=600" \
	-w start

psql <<- EOSQL
    CREATE USER MIMIC WITH PASSWORD '$MIMIC_PASSWORD';
    
    ALTER USER MIMIC WITH SUPERUSER;

    CREATE DATABASE MIMIC OWNER MIMIC;
    \c mimic;

    CREATE SCHEMA MIMIC_CORE;
    CREATE SCHEMA MIMIC_HOSP;
    CREATE SCHEMA MIMIC_ICU;
EOSQL

## 파일 확장자 체크(파일 확장자 csv.gz or csv)
# check for the admissions to set the extension
if [ -e "/mimic_data/core/admissions.csv.gz" ]; then
  COMPRESSED=1
  EXT='.csv.gz'
elif [ -e "/mimic_data/core/admissions.csv" ]; then
  COMPRESSED=0
  EXT='.csv'
else
  echo "Unable to find a MIMIC data file (admissions) in /mimic_data/core"
  echo "Did you map a local directory using `docker run -v /path/to/mimic/data:/mimic_data/core` ?"
  exit 1
fi

## core, hosp, icu 테이블 있는지 확인
# check for all the tables, exit if we are missing any

CORE_TABLES = 'admissions patients transfers'

HOSP_TABLES = 'd_hcpcs diagnoses_icd d_icd_diagnoses d_icd_procedures d_labitems drgcodes emar emar_detail hcpcsevents labevents microbiologyevents pharmacy poe poe_detail prescriptions procedures_icd services'

ICU_TABLES  = 'chartevents datetimeevents d_items icustays inputevents outputevents procedureevents'

# CORE_TABLES check for the table
for TBL in $CORE_TABLES; do
  if [ ! -e "/mimic_data/core/${TBL^^}$EXT" ];
  then
    echo "Unable to find ${TBL^^}$EXT in /mimic_data/core"
    exit 1
  fi
  echo "Found all tables in /mimic_data/core - beginning import from $EXT files."
done

# HOSP_TABLES check for the table
for TBL in $HOSP_TABLES; do
  if [ ! -e "/mimic_data/hosp/${TBL^^}$EXT" ];
  then
    echo "Unable to find ${TBL^^}$EXT in /mimic_data/hosp"
    exit 1
  fi
  echo "Found all tables in /mimic_data/hosp - beginning import from $EXT files."
done

# ICU_TABLES check for the table
for TBL in $ICU_TABLES; do
  if [ ! -e "/mimic_data/icu/${TBL^^}$EXT" ];
  then
    echo "Unable to find ${TBL^^}$EXT in /mimic_data/icu"
    exit 1
  fi
  echo "Found all tables in /mimic_data/icu - beginning import from $EXT files."
done

# checks passed - begin building the database
# /docker-entrypoint-initdb.d 경로 안에 있는 테이블 생성 스크립트 실행 
if [ ${PG_MAJOR:0:1} -eq 1 ]; then
echo "$0: running postgres_create_tables_pg10.sql"
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimiciv" < /docker-entrypoint-initdb.d/buildmimic/postgres/create.sql
else
echo "$0: running postgres_create_tables_pg.sql"
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimiciv" < /docker-entrypoint-initdb.d/buildmimic/postgres/create.sql
fi

# 테이블 적재 스크립트 실행(csv.gz or csv into table)
if [ $COMPRESSED -eq 1 ]; then
echo "$0: running postgres_load_data_gz.sql"
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimiciv" -v mimic_data_dir=/mimic_data < /docker-entrypoint-initdb.d/buildmimic/postgres/load_gz.sql
else
echo "$0: running postgres_load_data.sql"
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimiciv" -v mimic_data_dir=/mimic_data < /docker-entrypoint-initdb.d/buildmimic/postgres/load.sql
fi


# 테이블 인덱스 생성 스크립트 실행
echo "$0: running postgres_add_indexes.sql"
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimiciv" < /docker-entrypoint-initdb.d/buildmimic/postgres/index.sql

# 테이블 제약조건 스크립트 실행
echo "$0: running postgres_add_constraints.sql"
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimiciv" < /docker-entrypoint-initdb.d/buildmimic/postgres/constraint.sql

fi

echo 'Done!'