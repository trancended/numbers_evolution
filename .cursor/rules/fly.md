# Fly.io Deployment Rules - Numbers Evolution

## Timeline
- MVP1: Local development only
- Post-MVP1: Deploy to Fly.io
- No domain purchase required for MVP
- Deployment progressive: local → production

## Configuration
- Use `fly.toml` for application configuration
- Configure `[http_service]` section for scaling
- Set app name: `numbers-evolution` (or as configured)
- Region selection: choose closest to target users
- Automatic HTTPS/TLS via Let's Encrypt

## Environment Variables & Secrets
- Never commit secrets to repository
- Use `fly secrets set KEY=value` for sensitive data
- Required secrets:
  - `SECRET_KEY_BASE` - generate strong value for production
  - `DATABASE_URL` - Fly Postgres connection string
  - `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` - for AI features
  - `PHX_HOST` - application hostname for proper routing
- Secrets encrypted at rest and not shown in deployment logs
- Use `.env` file for local development (add to `.gitignore`)

## Database Configuration
- Use Fly Postgres for production database
- Enable connection pooling for better performance
- Configure pool size based on number of instances
- Connection via `DATABASE_URL` secret
- JSONB fields for strategy rules and simulation results
- SSL connection encryption enabled

## Deployment Process
- Use `fly deploy` for standard deployment
- Alternative: use deployment script `fly-deploy.sh` if available
- Check logs: `fly logs`
- Monitor status: `fly status`
- Access console: `fly ssh console`
- Deployment triggers from GitHub Actions CI/CD (optional post-MVP)

## Database Migrations
- Run migrations via `release_command` in `fly.toml`
- Alternative: Manual via `fly ssh console` then `eval "NumbersEvolution.Release.migrate()"`
- Always test migrations locally before production deployment
- Consider migration rollback strategy for complex changes
- Seed historical draws (100-200 Eurojackpot results) via migrations

## Monitoring & Health Checks
- Configure health checks in `fly.toml`
- Monitor metrics via Fly.io dashboard
- Track resource usage: CPU, RAM, network
- Set up alerts for critical errors
- Monitor simulation timeout rates and success rates
- Check AI API call failures and rate limits

## Scaling
- Configure auto-scaling in `fly.toml`
- Adjust VM size based on application needs
- Hobby tier sufficient for MVP: $5-10/month (1GB RAM)
- Consider horizontal scaling for higher traffic
- Multi-region deployment optional (single region sufficient for MVP)
- Use `fly scale` for dynamic adjustments
- Estimated traffic: 10-100 users initially (course project)

## Cost Considerations
- Hosting: ~$10-15/month (Fly.io + Postgres)
- AI API costs: ~$3-20/month depending on usage
  - Claude 3.5 Sonnet preferred (2.5x cheaper than GPT-4 Turbo)
  - Rate limit: 5 AI generations per user per day
- Total estimated cost: ~$13-35/month for MVP scale
- No monetization planned - costs from own pocket
- Cost acceptable for course project (10-50 users)

## Security
- Firewall: Fly.io managed, only necessary ports exposed
- HTTPS enforced automatically
- Database: encrypted connections (SSL)
- Secrets: encrypted at rest
- No direct access to sensitive data through logs
- Subscribe to Phoenix/Elixir security mailing lists for updates

## Disaster Recovery
- Database backups via Fly Postgres
- Application state mostly stateless (LiveView)
- Long-running simulations continue in background (Task.async)
- Users see results when returning after disconnection

## CI/CD Integration (Post-MVP)
- GitHub Actions for automated testing
- Run tests on every push/PR
- Automatic deployment after merge to main (optional)
- Pipeline must pass before merge
- No deployment automation in MVP1

