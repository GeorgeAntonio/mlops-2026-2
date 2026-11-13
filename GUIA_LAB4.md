# Laboratório 4 · Publicação e rollback da API

## Modelo e banco

O serviço requer um modelo Keras treinado e um banco Atlas com permissão de leitura e gravação. No diretório do projeto, o arquivo local `.env` recebe os quatro campos de `.env.example`. Use uma versão específica do artefato em `WANDB_MODELS`. As credenciais ficam no arquivo ignorado pelo Git.

Em Linux ou WSL, ative o ambiente Python 3.11 com as dependências de `requirements.txt`. Para criar o artefato com a classe e os exemplos fornecidos pela disciplina, execute na raiz do projeto:

```bash
python src/modules/intent_classifier/intent_classifier.py train \
  --config=dados_treinamento/confusion_config.yml \
  --training_data=dados_treinamento/confusion_examples.yml \
  --save_model=models/confusion/model.keras \
  --wandb_project=mlops-2026-2
```

Confira os arquivos `model.keras` e `model_config.yml` em W&B → Artifacts → confusion-clf. Copie a referência versionada para o arquivo local. No Atlas, use o cluster gratuito M0, um usuário de banco com acesso aos bancos da API e do CI, e os endereços de origem autorizados. Complete `MONGO_URL` com a URI de Drivers → Python.

## Verificação local e CI

```bash
python -m pip install -r requirements-dev.txt
python -m pytest -m 'not e2e' --cov=src
docker compose up -d --build
```

Depois do startup, faça GET /, POST /predictions com nome e texto fictícios e confira o registro no Atlas. Execute `E2E_BASE_URL=http://localhost:8000 python -m pytest -m e2e`. Se definir `APP_VERSION` no Compose, defina também `E2E_EXPECTED_VERSION` no processo de teste. Use `docker compose down` após o teste.

Cadastre como repository secrets do GitHub os quatro nomes de `.env.example`. O CI da main roda test e smoke. Em pull requests, roda test e docker-build. Aguarde as execuções correspondentes antes da primeira publicação.

## Primeira versão

Use o commit de preparação que contém a rota versionada e o CI reutilizável. O arquivo CD entra em um commit posterior ao da versão manual. No checkout do primeiro commit, autentique o Docker no GHCR e use a mesma imagem linux/amd64 para as duas etiquetas:

```bash
IMAGE=ghcr.io/georgeantonio/mlops-2026-2
docker build --platform linux/amd64 -t "$IMAGE:v1.0.0" -t "$IMAGE:latest" .
docker push "$IMAGE:v1.0.0"
docker push "$IMAGE:latest"
git tag v1.0.0
git push origin v1.0.0
```

Em Packages, torne a imagem pública e conceda acesso Write ao repositório em Manage Actions access. Confira se as duas etiquetas apontam para o mesmo digest.

## Azure e aprovação

Na assinatura e região autorizadas para o laboratório, use o grupo `mlops-2026-2`. O modelo `infra/lab4.bicep` descreve o primeiro deploy com a imagem pública v1.0.0, ingress HTTPS, porta 8000, 2 vCPU, 4 GiB e probe TCP com 60 tentativas a cada 10 segundos. O modelo cria a identidade do deploy e a atribuição Contributor no grupo. A escala configurada vai de zero a uma réplica. Ao usar o portal, aplique os mesmos parâmetros. Confira a disponibilidade regional e os créditos antes de criar recursos.

Ao implantar o Bicep, preencha os parâmetros protegidos no portal ou por entrada segura da CLI. Use a capitalização e os IDs reais do repositório para o subject de production. Nos repositórios novos do GitHub.com, o formato padrão é `repo:OWNER@OWNER_ID/REPO@REPO_ID:environment:production`. Confira a configuração do repositório antes de cadastrar a credencial federada. [Referência do GitHub](https://docs.github.com/en/actions/reference/security/oidc)

Valide a URL pública com GET / e uma predição real via POST /predictions. Cadastre os outputs azureClientId, azureTenantId e azureSubscriptionId como secrets AZURE_CLIENT_ID, AZURE_TENANT_ID e AZURE_SUBSCRIPTION_ID, respectivamente. Cadastre appUrl em Variables, como APP_URL. Crie o environment production com Required reviewers, selecione o revisor e permita deploys da main e das tags do exercício.

## Versões e evidências

1. Publique o commit que contém `.github/workflows/cd.yml` na main. Aguarde o CI verde.
2. Envie a tag v1.0.1 desse commit. Capture o job deploy em Waiting antes da aprovação humana e salve o run e o log do verify após a aprovação.
3. Publique v1.0.2. Aguarde a aprovação e o verify antes de capturar GET / na URL pública.
4. Em Actions → CD → Run workflow, escolha main e informe v1.0.1. Após a aprovação, capture o run com ci e release pulados, deploy e verify verdes e GET / exibindo v1.0.1.
5. Guarde também o Overview da aplicação com URL e imagem. Após conferir as capturas e autorizar a limpeza, exclua somente o grupo do laboratório e guarde a confirmação para o PDF.

