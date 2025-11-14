# To build:
#    make docker-build
# To push:
#    make docker-push

FROM golang:1.25.3-alpine AS build
ARG GIT_COMMIT

# Install Node.js for frontend build
RUN apk add --no-cache nodejs npm

ENV CGO_ENABLED=0 GOOS=linux
WORKDIR /src/stellar-disbursement-platform
ADD go.mod go.sum ./
RUN go mod download
COPY . ./

# Build the SEP-24 frontend before Go build (needed for embed directive)
WORKDIR /src/stellar-disbursement-platform/internal/serve/sep24frontend/app
RUN npm ci && npm run build

# Run go mod tidy (may fail due to network, but go.mod should already be tidy from local)
# If it fails, continue with build anyway since dependencies are already downloaded
WORKDIR /src/stellar-disbursement-platform
RUN (go mod tidy || true) && go build -o /bin/stellar-disbursement-platform -ldflags "-X main.GitCommit=$GIT_COMMIT" .


FROM alpine:3.22

RUN apk add --no-cache ca-certificates
# ADD migrations/ /app/migrations/
COPY --from=build /bin/stellar-disbursement-platform /app/
EXPOSE 8001
WORKDIR /app
ENTRYPOINT ["./stellar-disbursement-platform"]