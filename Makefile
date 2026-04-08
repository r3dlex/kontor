.PHONY: setup dev test test.coverage test.e2e lint release docker.up docker.down docker.build clean help

## help: Show this help message
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## //'

## setup: Install all dependencies and set up the database
setup:
	mix deps.get
	mix ecto.setup
	cd frontend && npm ci

## dev: Start the dev server (Postgres via Docker, Phoenix on localhost)
dev:
	docker compose --profile dev up -d
	iex -S mix phx.server

## test: Run backend + frontend unit tests
test:
	mix test
	cd frontend && npm test

## test.coverage: Run tests with coverage reports
test.coverage:
	mix coveralls.html
	cd frontend && npm run test:coverage

## test.e2e: Run Playwright end-to-end tests
test.e2e:
	cd frontend && npm run test:e2e

## lint: Run Credo (Elixir) and ESLint (frontend)
lint:
	mix credo --strict --min-priority higher
	cd frontend && npm run lint

## release: Build a Burrito zero-install binary for all targets
release:
	MIX_ENV=prod mix release

## docker.build: Build the Docker image
docker.build:
	docker compose build

## docker.up: Start all services (db + app) via Docker Compose
docker.up:
	docker compose --profile default up -d

## docker.down: Stop all Docker Compose services
docker.down:
	docker compose down

## clean: Remove build artifacts and deps
clean:
	rm -rf _build deps cover
	cd frontend && rm -rf node_modules coverage playwright-report
