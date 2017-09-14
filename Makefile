PROJECT=ddleak
IMG=img1

run: build
	docker-compose up run

build:
	docker build -f Dockerfile.build -t $(PROJECT)-$@ .
	docker run --rm $(PROJECT)-$@ | docker build -f Dockerfile -t $(IMG) -
