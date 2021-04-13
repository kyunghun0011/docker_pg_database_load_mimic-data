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

EOSQL

## 파일 확장자 체크(파일 확장자 csv.gz or csv)
# check for the admissions to set the extension
if [ -e "/mimic_data_core/admissions.csv.gz" ]; then
  COMPRESSED=1
  EXT='.csv.gz'
elif [ -e "/mimic_data_core/admissions.csv" ]; then
  COMPRESSED=0
  EXT='.csv'
else
  echo "Unable to find a MIMIC data file (admissions) in /mimic_data_core"
  echo "Did you map a local directory using `docker run -v /path/to/mimic/data:/mimic_data_core` ?"
  exit 1
fi

## core, hosp, icu 테이블 있는지 확인
# check for all the tables, exit if we are missing any

CORETABLES='admissions patients transfers'

HOSPTABLES='d_hcpcs diagnoses_icd d_icd_diagnoses d_icd_procedures d_labitems drgcodes emar emar_detail hcpcsevents labevents microbiologyevents pharmacy poe poe_detail prescriptions procedures_icd services'

ICUTABLES='chartevents datetimeevents d_items icustays inputevents outputevents procedureevents'

# CORETABLES check for the table
for TBL in $CORETABLES; do
  if [ ! -e "/mimic_data_core/${TBL}$EXT" ];
  then
    echo "Unable to find ${TBL}$EXT in /mimic_data_core"
    exit 1
  fi
  echo "Found all tables in /mimic_data_core - beginning import from $EXT files."
done

# HOSPTABLES check for the table
for TBL in $HOSPTABLES; do
  if [ ! -e "/mimic_data_hosp/${TBL}$EXT" ];
  then
    echo "Unable to find ${TBL}$EXT in /mimic_data_hosp"
    exit 1
  fi
  echo "Found all tables in /mimic_data_hosp - beginning import from $EXT files."
done

# ICUTABLES check for the table
for TBL in $ICUTABLES; do
  if [ ! -e "/mimic_data_icu/${TBL}$EXT" ];
  then
    echo "Unable to find ${TBL}$EXT in /mimic_data_icu"
    exit 1
  fi
  echo "Found all tables in /mimic_data_icu - beginning import from $EXT files."
done

echo 'Found all tables in /mimic_data_core!'
echo 'Found all tables in /mimic_data_hosp!'
echo 'Found all tables in /mimic_data_icu !'

## 도커 컨테이너 내부 /docker-entrypoint-initdb.d 경로의 스크립트 실행 
# checks passed - begin building the database
if [ ${PG_MAJOR:0:1} -eq 1 ]; then
echo "$0: running create.sql"
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimic_core" < /docker-entrypoint-initdb.d/buildmimic/postgres/create.sql
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimic_hosp" < /docker-entrypoint-initdb.d/buildmimic/postgres/create.sql
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimic_icu" < /docker-entrypoint-initdb.d/buildmimic/postgres/create.sql
fi

# 테이블 적재 스크립트 실행(csv.gz or csv into table)
if [ $COMPRESSED -eq 1 ]; then
echo "$0: running load_gz.sql"
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimic_core" -v mimic_data_dir=/mimic_data_core < /docker-entrypoint-initdb.d/buildmimic/postgres/load_gz.sql
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimic_hosp" -v mimic_data_dir=/mimic_data_hosp < /docker-entrypoint-initdb.d/buildmimic/postgres/load_gz.sql
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimic_icu" -v mimic_data_dir=/mimic_data_icu < /docker-entrypoint-initdb.d/buildmimic/postgres/load_gz.sql

else
echo "$0: running load.sql"
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimic_core" -v mimic_data_dir=/mimic_data_core < /docker-entrypoint-initdb.d/buildmimic/postgres/load.sql
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimic_hosp" -v mimic_data_dir=/mimic_data_hosp < /docker-entrypoint-initdb.d/buildmimic/postgres/load.sql
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimic_icu" -v mimic_data_dir=/mimic_data_icu < /docker-entrypoint-initdb.d/buildmimic/postgres/load.sql
fi

# 테이블 인덱스 생성 스크립트 실행
echo "$0: running postgres_add_indexes.sql"
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimic_core" < /docker-entrypoint-initdb.d/buildmimic/postgres/index.sql
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimic_hosp" < /docker-entrypoint-initdb.d/buildmimic/postgres/index.sql
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimic_icu" < /docker-entrypoint-initdb.d/buildmimic/postgres/index.sql


# 테이블 제약조건 스크립트 실행
echo "$0: running postgres_add_constraints.sql"
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimic_core" < /docker-entrypoint-initdb.d/buildmimic/postgres/constraint.sql
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimic_hosp" < /docker-entrypoint-initdb.d/buildmimic/postgres/constraint.sql
psql "dbname=mimic user='$POSTGRES_USER' options=--search_path=mimic_icu" < /docker-entrypoint-initdb.d/buildmimic/postgres/constraint.sql

fi

echo 'Done!'