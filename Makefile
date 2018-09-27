# main commands
all: maps push_maps

clean:
	rm -rf exports/*.png

# command for creating maps
maps: data/parameters/parameters.yml code/create_maps.R data/grid/grid.shp code/extract_locations_from_ebird_records.R
	@docker run --name=bba -w /tmp -dt 'brisbanebirdteam/build-env:latest' \
	&& docker cp . bba:/tmp/ \
	&& docker cp "$(HOME)/.Renviron" bba:/root/.Renviron \
	&& docker exec bba sh -c "Rscript /tmp/code/create_maps.R" \
	&& docker exec bba sh -c "zip -r exports.zip exports" \
	&& docker cp bba:/tmp/exports.zip . \
	&& unzip -o exports.zip \
	&& rm exports.zip || true
	@docker stop -t 1 bba || true && docker rm bba || true

# command for pushing maps
push_maps: exports/*.png push_maps.R
	@docker run --name=bba -w /tmp -dt 'brisbanebirdteam/build-env:latest' \
	&& docker cp . bba:/tmp/ \
	&& docker cp "$(HOME)/.Renviron" bba:/root/.Renviron \
	&& docker exec bba sh -c "zip -r maps.zip exports" \
	&& docker exec bba sh -c "Rscript /tmp/code/push_maps.R" \
	&& docker exec bba sh -c "rm assets/maps.zip" || true
	@docker stop -t 1 bba || true && docker rm bba || true

# docker container commands
## pull image
pull_image:
	@docker pull 'brisbanebirdteam/build-env:latest'

## remove image
rm_image:
	@docker image rm 'brisbanebirdteam/build-env:latest'

## start container
start_container:
	@docker run --name=bba -w /tmp -dt 'brisbanebirdteam/build-env:latest'

## kill container
stop_container:
	@docker stop -t 1 bba || true && docker rm bba || true

.PHONY: maps push_maps clean pull_image rm_image start_container stop_container
