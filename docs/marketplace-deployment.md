**Marketplace Deployment Requirements**

### Overview

Marketplace is a web application developed in Ruby using the Ruby on Rails framework. It is designed to provide a scalable and efficient platform, utilizing containerized environments for deployment.

A more detailed description of the application and all additional environment variables that can be used are documented in the project's README file, which can be found in the repository: [https://github.com/cyfronet-fid/whitelabel-marketplace/blob/development/README.md](https://github.com/cyfronet-fid/whitelabel-marketplace/blob/development/README.md).

Marketplace Docker images are published in the GitHub Container Registry package connected with the repository: [https://github.com/cyfronet-fid/whitelabel-marketplace/pkgs/container/whitelabel-marketplace](https://github.com/cyfronet-fid/whitelabel-marketplace/pkgs/container/whitelabel-marketplace). Deployments should use the GHCR image (`ghcr.io/cyfronet-fid/whitelabel-marketplace`) instead of building the image locally or using the historical Docker Hub image. For production-like deployments, pinning a specific released tag is recommended instead of relying on `latest`.

For the most up-to-date information about application features, configuration options, and deployment variables, please refer to this README.

### Required Dependencies

- **Ruby on Rails**: Core framework for the application.
- **PostgreSQL**: Primary relational database.
- **Elasticsearch**: Search engine for indexing and querying data efficiently.
- **Redis**: In-memory data store, used for caching and background job processing.

### Required Integrations

#### Authentication & SSO Integration

The application requires integration with Single Sign-On (SSO). We recommend using one of the following solutions:

- **EOSC Beyond DS**: [MyAccessID](https://eosc-beyond-ds.myaccessid.org)
- **OAuth2-based solutions**: Utilizing **Keycloak** or similar identity management systems.

#### Google reCAPTCHA

To validate submitted orders and prevent spam or automated abuse, the application requires Google reCAPTCHA integration. This ensures a secure and verified order submission process.

#### Email Service

The Marketplace application needs access to an email account to send notifications via email. This is crucial for user communication, order confirmations, and system alerts.

### Optional Integrations

- **JIRA**: Can be integrated for order management and tracking. In JIRA, orders related to the Marketplace system are processed, and communication occurs via REST API. The only JIRA instance ready for integration is available at [https://jira.egi.eu](https://jira.egi.eu), as it has the required workflows and custom fields necessary for order management.
- **BOS (Backoffice Ordering System)**: Optional integration for order management. BOS processes orders related to the Marketplace system, with communication handled through REST API. Repository: [BOS GitHub](https://github.com/cyfronet-fid/backoffice-ordering-system)
- **RAiD**: Integration with RAiD is switched off by default. It can be enabled by adding `RAID_ON` environmental variable to `.env` file and setting it to `true`.The future requires ROR data from Zenodo, which can be saved in database with rake ror:add_rors rake task. The task should be rerun monthly as the new RORs dumps are published by Zenodo.

### Deployment Architecture

The Marketplace application is containerized, and its deployment includes multiple services managed via Docker Compose. The architecture consists of core services required for the application to function properly:

1. **web** - Main web application container running Puma server that handles HTTP requests. This container is responsible for serving the Rails application to users. It runs database migrations on startup and reindexes search data.

2. **worker** - Background processing container running Sidekiq that processes asynchronous jobs like email sending, data processing, and other time-consuming tasks outside the main request cycle. This ensures the application remains responsive while handling resource-intensive operations.

3. **db** - PostgreSQL database for storing application data.

4. **el** - Elasticsearch service for fast and efficient search capabilities.

5. **redis** - In-memory store used by Sidekiq for job queuing and as a cache store for the application.

The containers are configured as follows:

```yaml
services:
  redis:
    image: redis:7
    restart: always
    volumes:
      - redis-data:/data
    command: ["redis-server", "--appendonly", "yes"]

  el:
    image: elasticsearch:7.5.0
    restart: always
    environment:
      - discovery.type=single-node
      - cluster.routing.allocation.disk.threshold_enabled=false
    volumes:
      - es-data:/usr/share/elasticsearch/data

  db:
    image: postgres:16
    environment:
      POSTGRES_USER: mpuser
      POSTGRES_PASSWORD: mppass
      POSTGRES_DB: mp
    restart: always
    volumes:
      - postgres-data:/var/lib/postgresql/data

  web:
    image: ghcr.io/cyfronet-fid/whitelabel-marketplace:latest
    restart: always
    command: bash -c "./bin/rails db:migrate && ./bin/rake searchkick:reindex:all && bundle exec puma "
    env_file:
      - marketplace.env
    ports:
      - ${MP_PORT:-3000}:3000
    volumes:
      - media-data:/marketplace/media
    depends_on:
      - db
      - el
      - redis

  worker:
    image: ghcr.io/cyfronet-fid/whitelabel-marketplace:latest
    restart: always
    command: bash -c "bundle exec sidekiq "
    env_file:
      - marketplace.env
    volumes:
      - media-data:/marketplace/media
    depends_on:
      - db
      - el
      - redis

volumes:
  postgres-data:
  media-data:
  redis-data:
  es-data:
```

### Environment Configuration

1. In the app root directory, create the `marketplace.env` file based on the example: `cp .env.example marketplace.env`
2. Edit the `marketplace.env` file and fill in MANDATORY values with <YOUR\_...> placeholders

#### Service Catalogue Data Import

The Marketplace Whitelabel does not hold its own copy of the provider and resource data: a node that is connected to a Service Catalogue (Resource Catalogue) imports it from there. Whatever is onboarded in the Service Catalogue (providers, resources, datasources, guidelines, etc.) shows up in the Marketplace only after the next import has run.

There are two ways to run the import:

- **Automatically (recommended)** - a scheduled job synchronises the Marketplace with the Service Catalogue every 3 minutes by default. After onboarding or changing anything in the Service Catalogue, wait around 3 minutes to see the result in the Marketplace, no manual action is needed. See [Auto Import](#auto-import).
- **Manually** - run the import on demand, e.g. for the initial data load or for troubleshooting. See [Manual Import](#manual-import).

In both cases, configure the relevant variables in `marketplace.env` first (see [Environment Variables](#environment-variables)).

##### Environment Variables

| Variable                                    | Description                                                                                                                                                                                                                    | Default                                      |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------- |
| `IMPORT_CLIENT_ID` / `IMPORT_CLIENT_SECRET` | OAuth2 client credentials used to automatically obtain an access token for the Service Catalogue API. The values should be obtained according to the instructions from Nicolas. Required only if `MP_IMPORT_TOKEN` is not set. | — (required unless `MP_IMPORT_TOKEN` is set) |
| `MP_IMPORT_TOKEN`                           | Access token for the Service Catalogue API. Derived automatically from `IMPORT_CLIENT_ID`/`IMPORT_CLIENT_SECRET`; only needs to be exported manually if a pre-obtained token should be used instead.                           | derived automatically                        |
| `MP_IMPORT_EOSC_REGISTRY_URL`               | Service Catalogue API base URL. Must include the `/api` suffix, e.g. `https://providers.sandbox.eosc-beyond.eu/api`.                                                                                                           | — (required)                                 |
| `AUTO_IMPORT_ALL_ENABLED`                   | Enables the scheduled automatic import (see [Auto Import](#auto-import) below). Has no effect on manual imports.                                                                                                               | `false`                                      |
| `AUTO_IMPORT_ALL_CRON`                      | Cron expression controlling how often the scheduled import runs. Has no effect on manual imports.                                                                                                                              | `*/3 * * * *`                                |

##### Manual Import

Once the variables above are configured, an import can be run on demand inside the application container:

```bash
docker compose exec web bundle exec rake import:all
```

`import:all` runs the full set of importers in order (`vocabularies`, `catalogues`, `providers`, `resources`, `datasources`, `guidelines`). A single collection can be imported instead by running its task directly, e.g.:

```bash
docker compose exec web bundle exec rake import:providers
```

##### Auto Import

The Marketplace can keep itself in sync with the Service Catalogue automatically. A scheduled job (Sidekiq Cron, running inside the `worker` container) runs the full `import:all` synchronisation **every 3 minutes** by default.

> **Note:** the schedule is off until `AUTO_IMPORT_ALL_ENABLED=true` is set. Once it is enabled, anything onboarded or updated in the Service Catalogue becomes visible in the Marketplace within about 3 minutes (plus the time the import itself takes), so if you have just onboarded something and do not see it yet, wait a few minutes before troubleshooting.

To enable it, set the following in `marketplace.env` and restart the `worker` service:

```env
AUTO_IMPORT_ALL_ENABLED=true
# Optional - how often the import runs (default: every 3 minutes)
AUTO_IMPORT_ALL_CRON="*/3 * * * *"
```

Details:

- Scheduled runs execute the same `import:all` task as the [manual import](#manual-import), so the result is identical.
- Runs never overlap: the job uses a dedicated `imports` queue processed by a single worker, so a run that takes longer than the interval simply delays the next one.
- Each run's status can be checked in the Sidekiq Web UI (mounted at `/admin/sidekiq`, the schedule itself under its **Cron** tab).
- A longer interval (e.g. `*/15 * * * *` for every 15 minutes) can be set through `AUTO_IMPORT_ALL_CRON` if the Service Catalogue should be queried less often; the waiting time after onboarding grows accordingly.

### Reverse Proxy Configuration

To provide secure HTTPS connections to the application, an NGINX reverse proxy server should be configured in front of the Marketplace container. This is essential for production environments as it handles SSL termination and can provide additional security features.

#### NGINX Configuration

Below is a recommended NGINX configuration for the Marketplace application:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name marketplace.example.com;

    # Redirect all HTTP traffic to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name marketplace.example.com;

    # SSL certificates (using Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/marketplace.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/marketplace.example.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    root /var/www/html;
    index index.html index.htm;

    # Proxy settings for the Marketplace application
    location / {
        try_files $uri/index.html $uri @mp-app;
    }

    location @mp-app {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Host $http_host;
        proxy_redirect off;

        # WebSocket support (for live updates)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

This configuration:

- Redirects all HTTP traffic to HTTPS
- Uses Let's Encrypt for SSL certificates
- Proxies all requests to the Marketplace application running on port 3000
- Includes proper headers for forwarding client information

### Deployment Steps

1. **Prepare Infrastructure**:

   - Set up a server with Docker and Docker Compose installed.
   - Install NGINX for reverse proxy.
   - Obtain SSL/TLS certificates (recommended to use Let's Encrypt with Certbot).

2. **Configure Reverse Proxy**:

   - Install NGINX on the host machine.
   - Set up Let's Encrypt certificates using Certbot (`certbot --nginx -d marketplace.example.com`).
   - Set up the reverse proxy configuration as shown above.
   - Adjust the `server_name` to match your domain.

3. **Create Environment Configuration**:

   - Provide a `.env` file (e.g., `marketplace.env`) with required environment variables.
   - Set `ROOT_URL` to your domain name.

4. **Deploy the Application**:

   - Run `docker-compose up -d` to start all services in the background.

5. **Configure DNS**:

   - Point your domain (e.g., marketplace.example.com) to your server's IP address.

6. **Verify the Deployment**:

   - Check logs using `docker-compose logs -f` to ensure all services start correctly.
   - Check reverse proxy logs for any errors.
   - Ensure the application is accessible at your domain with HTTPS.

7. **Monitor and Scale**:
   - Monitor container logs and adjust resource allocation if needed.
   - Set up regular backups of volumes (especially database and media).

### Security & Maintenance

- Ensure that database credentials are stored securely.
- Use strong SSL/TLS configuration in your reverse proxy.
- Set up automatic certificate renewal if using Let's Encrypt.
- Configure regular backups of your data volumes.
- Keep your Docker images and containers updated.
- Regularly update dependencies and containers.
- Consider setting up monitoring for your services.
- Enable Sentry integration for error tracking and monitoring - the application supports this integration via the `SENTRY_DSN` environment variable in the `marketplace.env` file. This will help you track and be notified about runtime errors in the application.

This document outlines the deployment requirements and considerations for Marketplace to ensure a smooth, secure, and scalable deployment. For additional information about configuration parameters, customization options, and detailed application features, please refer to the official documentation in the project's README at [https://github.com/cyfronet-fid/whitelabel-marketplace/blob/development/README.md](https://github.com/cyfronet-fid/whitelabel-marketplace/blob/development/README.md).
