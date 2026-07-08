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

Create a `marketplace.env` file with the following configuration:

```env
SECRET_KEY_BASE=your-secure-random-key

# STORAGE_DIR path should be mounted as a volume in the docker container
STORAGE_DIR=/marketplace/media

ROOT_URL=

DATABASE_URL=postgres://mpuser:mppass@db/mp
ELASTICSEARCH_URL=el
DISABLE_DATABASE_ENVIRONMENT_CHECK=1
RAILS_SERVE_STATIC_FILES=1
REDIS_URL=redis://redis:6379/0

CHECKIN_HOST=core-proxy.sandbox.eosc-beyond.eu
CHECKIN_IDENTIFIER=
CHECKIN_SECRET=


SMPT_ADDRESS=
SMPT_USERNAME=
SMPT_PASSWORD=
FROM_EMAIL=

ASSET_HOST=$NO_PROTOCOL_ROOT_URL
ASSET_PROTOCOL=https

# ONLY FOR JIRA INTEGRATIONS
MP_JIRA_USERNAME=
MP_JIRA_PASSWORD=
MP_JIRA_URL=https://jira.egi.eu
MP_JIRA_ISSUE_TYPE_ID=10204
MP_JIRA_WF_TODO=10309
MP_JIRA_WF_IN_PROGRESS=3
MP_JIRA_WF_WAITING_FOR_RESPONSE=10310
MP_JIRA_WF_DONE=10311
MP_JIRA_WF_REJECTED=10103
MP_JIRA_WEBHOOK_SECRET=
MP_JIRA_PROJECT=EOSCSOPR
MP_JIRA_FIELD_Order_reference=customfield_10254
MP_JIRA_FIELD_CI_Name=customfield_10225
MP_JIRA_FIELD_CI_Surname=customfield_10226
MP_JIRA_FIELD_CI_Email=customfield_10227
MP_JIRA_FIELD_CI_DisplayName=customfield_10228
MP_JIRA_FIELD_CI_EOSC_UniqueID=customfield_10229
MP_JIRA_FIELD_CI_Institution=customfield_10243
MP_JIRA_FIELD_CI_Department=customfield_10244
MP_JIRA_FIELD_CI_SupervisorName=customfield_10248
MP_JIRA_FIELD_CI_SupervisorProfile=customfield_10249
MP_JIRA_FIELD_CP_CustomerTypology=customfield_10250
MP_JIRA_FIELD_CP_ReasonForAccess=customfield_10251
MP_JIRA_FIELD_CI_DepartmentalWebPage=customfield_10245
MP_JIRA_FIELD_SELECT_VALUES_CP_CustomerTypology_single_user=10187
MP_JIRA_FIELD_SELECT_VALUES_CP_CustomerTypology_research=10188
MP_JIRA_FIELD_SELECT_VALUES_CP_CustomerTypology_private_company=10189
MP_JIRA_FIELD_SO_1=customfield_10711
MP_JIRA_FIELD_CP_ScientificDiscipline=customfield_10706
MP_JIRA_FIELD_SO_ProjectName=customfield_10705
MP_JIRA_FIELD_CP_UserGroupName=customfield_10252
MP_JIRA_FIELD_CP_ProjectInformation=customfield_10253
MP_JIRA_FIELD_CP_INeedAVoucher=customfield_10716
MP_JIRA_FIELD_SELECT_VALUES_CP_INeedAVoucher_true=10705
MP_JIRA_FIELD_SELECT_VALUES_CP_INeedAVoucher_false=10706
MP_JIRA_FIELD_CP_VoucherID=customfield_10710
MP_JIRA_FIELD_CP_Platforms=customfield_10708
MP_JIRA_FIELD_SELECT_VALUES_SO_OfferType_normal=10906
MP_JIRA_FIELD_SELECT_VALUES_SO_OfferType_open_access=10907
MP_JIRA_FIELD_SELECT_VALUES_SO_OfferType_catalog=10908
MP_JIRA_FIELD_SO_OfferType=customfield_10906

RECAPTCHA_SITE_KEY=
RECAPTCHA_SECRET_KEY=

#optional sentry integrations
SENTRY_DSN=

PROFILE_4_ENABLED=true
EXTERNAL_LANDING_PAGE=false

MP_WHITELABEL=true
MP_ENABLE_EXTERNAL_SEARCH=false
ENABLE_COMMONS=false

RAID_ON=false

# Service Catalogue data import
# IMPORT_CLIENT_ID and IMPORT_CLIENT_SECRET should be obtained according to the instructions from Nicolas.
IMPORT_CLIENT_ID=
IMPORT_CLIENT_SECRET=
# MP_IMPORT_EOSC_REGISTRY_URL must point to your Service Catalogue API base URL. Please include /api at the end. For example:
MP_IMPORT_EOSC_REGISTRY_URL=https://providers.sandbox.eosc-beyond.eu/api
```

#### Service Catalogue Data Import

If a node should import data from a Service Catalogue, configure the import credentials in `marketplace.env` before running the import task. `IMPORT_CLIENT_ID` and `IMPORT_CLIENT_SECRET` are used to obtain an access token automatically, so operators no longer need to export `MP_IMPORT_TOKEN` manually. The values should be obtained according to the instructions from Nicolas.

`MP_IMPORT_EOSC_REGISTRY_URL` must point to the Service Catalogue API base URL. Include the `/api` suffix, for example:

```env
MP_IMPORT_EOSC_REGISTRY_URL=https://providers.sandbox.eosc-beyond.eu/api
```

After the variables are configured, the import can be run inside the application container:

```bash
docker compose exec web bundle exec rake import:all
```

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
