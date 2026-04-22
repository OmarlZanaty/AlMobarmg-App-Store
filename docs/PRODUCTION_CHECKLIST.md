# Al Mobarmg Store — Production Checklist

## Server
- [ ] EC2 t3.medium or larger
- [ ] 20GB+ disk with < 70% used
- [ ] Elastic IP assigned (IP doesn't change on reboot)
- [ ] Security groups: ports 22, 80, 443 open; port 8080 closed to public

## Domain & SSL (when ready)
- [ ] Domain purchased and DNS pointing to EC2 IP
- [ ] Certbot SSL certificate installed: `sudo certbot --nginx -d yourdomain.com`
- [ ] Nginx config updated to use domain name instead of IP
- [ ] FRONTEND_URL in .env updated to `https://yourdomain.com`
- [ ] HTTP → HTTPS redirect enabled in Nginx

## Environment Variables
- [ ] DATABASE_URL uses strong password (no special chars that break config files)
- [ ] JWT_SECRET is 64+ random chars
- [ ] JWT_REFRESH_SECRET is different from JWT_SECRET
- [ ] MOBSF_API_KEY copied from http://localhost:8000
- [ ] VIRUSTOTAL_API_KEY set
- [ ] RESEND_API_KEY set and domain verified
- [ ] R2 bucket created and credentials set (when file uploads needed)
- [ ] STRIPE_SECRET_KEY set (when payments needed)
- [ ] ANTHROPIC_API_KEY set (when AI reports needed)

## Services
- [ ] almobarmg-api service: `systemctl is-active almobarmg-api`
- [ ] almobarmg-worker service: `systemctl is-active almobarmg-worker`
- [ ] nginx service: `systemctl is-active nginx`
- [ ] postgresql service: `systemctl is-active postgresql`
- [ ] redis-server service: `systemctl is-active redis-server`
- [ ] MobSF Docker container: `docker ps` shows mobsf as healthy

## Database
- [ ] All migrations applied: `python -m backend.migrations.run`
- [ ] Tables created: `psql -U almobarmg_user -d almobarmg -c "\dt"`
- [ ] Admin user created manually (see below)

## Create Admin User (run once)
```bash
source /home/ubuntu/venv/bin/activate
cd /home/ubuntu/almobarmg
python3 scripts/create_admin.py admin@almobarmg.com "Admin" "CHANGE_THIS_PASSWORD"
```

## Smoke Test
- [ ] Run: `bash scripts/smoke_test.sh`
- [ ] All 10 checks pass

## Flutter
- [ ] `flutter build web --release` completes without errors
- [ ] Web build deployed to /var/www/almobarmg/
- [ ] `flutter build apk --release` completes (for Android store app)
- [ ] APK tested on physical Android device
- [ ] Install Unknown Apps permission granted to Al Mobarmg Store app
- [ ] In-app install tested with a real APK

## Security
- [ ] .env file permissions: `chmod 600 /home/ubuntu/.env`
- [ ] .gitignore includes .env
- [ ] No secrets in git history: `git log --all --full-history -- .env`
- [ ] Rate limiting active (test: curl loop to /api/auth/login)
- [ ] CORS only allows FRONTEND_URL
