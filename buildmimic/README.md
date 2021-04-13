# Installing Docker with MIMIC-IV

# 디렉토리 구조
```
BASE_DIR  
│
└───core
│   │   admissions.csv
│   │   patients.csv
│   │   transfers.csv
└───hosp
│   │   d_hcpcs.csv
│   │   ...
└───icu
│   │   d_items.csv
│   │   ...
```

# Building the MIMIC database with Docker
도커 파일 참고합니다.
[Docker](https://www.docker.com/) 

## Step 0: Clone this repository to your host machine
로컬에 프로젝트 클론합니다.

## Step 1: Obtain the MIMIC csv data files
로컬에 있는 csv파일을 경로 및 확장자 확인합니다. 압축 풀거나 풀지 않아도 상관없습니다.
만약 압축을 풀고 진행을 한다면 아래와 같은 .sh 파일을 실행합니다.

    cd /mimic_code/buildmimic/docker
    source unzip_csv.sh /HOST/mimic/csv

## Step 2: Build the Docker image
도커 파일을 빌드 합니다.

    cd /mimic_code/buildmimic/docker
    docker build -t postgres/mimic .
꼭 마지막에 "." 작성합니다.

생성된 도커 이미지는 아래 명령어로 확인합니다.

    docker images

    REPOSITORY                      TAG                 IMAGE ID            CREATED             SIZE
    postgres/mimic                  latest              a664dd0d7238        2 minutes ago       349.4 MB

## Step 3: Deploy the container
빌드된 이미지를 컨테이너에 배포합니다.(인스턴스 생성)
환경변수로 아래와 같이 전달합니다.

    docker run \
    --name mimic \
    -p HOST_PORT:5432 \
    -e BUILD_MIMIC=1 \
    -e POSTGRES_PASSWORD=POSTGRES_USER_PASSWORD \
    -e MIMIC_PASSWORD=MIMIC_USER_PASSWORD \
    -v /HOST/mimic_data/csv:/mimic_data \
    -v /HOST/PGDATA_DIR:/var/lib/postgresql/data \
    -d postgres/mimic

구체적인 설명은 아래와 같습니다.:

* 컨테이너 이름  `mimic`

* `HOST_PORT` (호스트의 포트는 적절하게 변경 가능합니다.)

*  `BUILD_MIMIC=0` setup.sh 실행하지 않고 넘어갑니다. 
*  `BUILD_MIMIC=1` setup.sh 유저, 데이터베이스, 스키마, 테이블, 테이블 적재 스크립트 실행합니다. 
  
* `postgres` pg 로그인 패스워드 지정합니다. 

* `mimic` pg 유저 패스워드 지정합니다.

* `/mimic_data`는 도커 컨테이너의 폴더로서 호스트의 `/HOST/mimic_data/csv` 폴더와 바인딩 합니다.
그러면 csv 파일을 테이블로 적재가 가능합니다.

* /var/lib/postgresql/data 폴더는 호스트의 `/HOST/PG_DATA`와 바인딩 합니다. 그러면 컨테이너에서 발생된 데이터는 바인딩한 호스트의 폴더에 저장이 되어 
컨테이너가 종료가 되어도 데이터를 재사용 할 수 있습니다.

... ubuntu 16.04 example 

    docker run \
    --name mimic \
    -p 5555:5432 \
    -e BUILD_MIMIC=1 \
    -e POSTGRES_PASSWORD=postgres \
    -e MIMIC_PASSWORD=mimic \
    -v /data/mimic3/version_1_4:/mimic_data \
    -v /data/docker/mimic:/var/lib/postgresql/data \
    -d postgres/mimic

도커 프로세스 전체 확인합니다.
    docker ps -a

    CONTAINER ID        IMAGE             COMMAND                CREATED       STATUS        PORTS                             NAMES
    YOUR_CONTAINER_ID   postgres/mimic    "/docker-entrypoint.   3 days ago    Up 3 days     0.0.0.0:32777->5432/tcp           mimic

도커 파일 삭제 명령어(f=force)

    `docker rm -f <hash or image name>`

도커 이미지 삭제 명령어(f=force)

    `docker rmi -f <hash or image name>`


도커 로그 확인

    docker logs -f YOUR_CONTAINER_ID

도커 컨테이너 bash 접속

    sudo docker exec -it YOUR_CONTAINER_ID /bin/bash

[MIMIC-III]: https://mimic.physionet.org/tutorials/install-mimic-locally-ubuntu/
[MIMIC-IV]: https://mimic-iv.mit.edu/docs/access/
[postgresql]: https://www.postgresql.org/docs/10/app-psql.html