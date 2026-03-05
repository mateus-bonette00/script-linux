# Template de Repositorio de App

Este template contem arquivos basicos para deploy no desktop via Docker Compose.

## Arquivos incluidos

- `.env.example`
- `.gitignore`
- `docker-compose.yml`
- `scripts/deploy.sh`
- `scripts/update.sh`

## Uso rapido

1. Copie estes arquivos para a raiz do seu repositorio.
2. Ajuste `docker-compose.yml` para seu backend/frontend.
3. No desktop, clone o repositorio em `~/Documentos/apps/<nome-repo>`.
4. Crie `.env`:

```bash
cp .env.example .env
nano .env
chmod 600 .env
```

5. Rode deploy:

```bash
chmod +x scripts/deploy.sh scripts/update.sh
./scripts/deploy.sh
```

6. Para atualizar depois:

```bash
./scripts/update.sh
```
