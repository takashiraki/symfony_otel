# symfony_otel

Symfony 8.0 アプリケーションに OpenTelemetry による分散トレーシングと Prometheus/Grafana による可観測性スタックを統合した Docker 環境です。

## 構成

| コンポーネント       | 技術スタック                     |
| -------------------- | -------------------------------- |
| Web フレームワーク   | Symfony 8.0 (PHP 8.4+)           |
| データベース         | SQLite (Doctrine ORM)            |
| テンプレートエンジン | Twig                             |
| フロントエンド       | Tailwind CSS                     |
| 分散トレーシング     | OpenTelemetry SDK + 自動計装     |
| トレース収集         | Grafana Tempo (OTLP HTTP/gRPC)   |
| メトリクス収集       | Prometheus                       |
| ダッシュボード       | Grafana                          |
| リバースプロキシ     | nginx-proxy (Let's Encrypt 対応) |
| コンテナ管理         | Docker / Docker Compose          |

## アーキテクチャ

```
[ブラウザ]
    │
    ▼
[nginx-proxy] ← docker_proxy_network
    │
    ▼
[Symfony App: symfony_otel] ← symfony/
    │
    ├─ OTLP (HTTP) ──► [Tempo] ──► [Grafana]
    │                                  ▲
    └─ metrics ──► [Prometheus] ────────
```

3つの Git サブモジュールで構成されています:

- `docker_proxy_network` — nginx-proxy + Let's Encrypt によるリバースプロキシ
- `docker_otel` — Prometheus / Grafana / Tempo の可観測性スタック
- `symfony` — Symfony アプリケーションコンテナ

## 前提条件

- Docker
- Docker Compose

```bash
make check-deps
```

## セットアップ

### クイックセットアップ（推奨）

```bash
make quick-setup
```

`quick-setup` は以下を順に実行します: `check-deps` → `init` → `up` → `build-tailwind` → `migrate`

### ステップごとのセットアップ

```bash
# 1. サブモジュールの初期化・ネットワーク作成・イメージビルド
make init

# 2. 全コンテナを起動
make up

# 3. Tailwind CSS のビルド
make build-tailwind

# 4. データベースマイグレーションの実行
make migrate
```

## アクセス先

| サービス       | URL                                      |
| -------------- | ---------------------------------------- |
| Symfony アプリ | http://symfony-otel.localhost            |
| Grafana        | http://symfony-otel-grafana.localhost    |
| Prometheus     | http://symfony-otel-prometheus.localhost |
| Tempo          | http://symfony-otel-tempo.localhost      |

> `/etc/hosts` にエントリが必要な場合は `127.0.0.1 symfony-otel.localhost` 等を追加してください。

## 主なコマンド

```bash
make up             # 全コンテナを起動
make down           # 全コンテナを停止
make migrate        # データベースマイグレーション実行
make build-tailwind # Tailwind CSS のビルド
make check-deps     # 依存ツールの確認
```

## OpenTelemetry 設定

コンテナには以下の環境変数が設定されています:

| 変数                          | 値                               |
| ----------------------------- | -------------------------------- |
| `OTEL_PHP_AUTOLOAD_ENABLED`   | `true`                           |
| `OTEL_SERVICE_NAME`           | `symfony_otel`                   |
| `OTEL_TRACES_EXPORTER`        | `otlp`                           |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://symfony-otel-tempo:4318` |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf`                  |

自動計装パッケージ:
- `opentelemetry-auto-symfony` — HTTP リクエスト/レスポンスのトレース
- `opentelemetry-auto-doctrine` — データベースクエリのトレース
- `opentelemetry-auto-psr18` — 外部 HTTP クライアントのトレース

## ディレクトリ構成

```
symfony_otel/
├── docker_proxy_network/   nginx-proxy コンテナ (サブモジュール)
├── docker_otel/            Prometheus / Grafana / Tempo (サブモジュール)
├── symfony/                Symfony アプリコンテナ (サブモジュール)
│   └── src/my_symfony/     Symfony アプリケーション本体
│       ├── src/
│       │   ├── Controller/ HTTPコントローラ (Home, SignIn, SignUp)
│       │   ├── Entity/     Doctrine エンティティ (Account)
│       │   ├── Repository/ データベースリポジトリ
│       │   ├── Command/    コンソールコマンド
│       │   └── Event/      イベント・イベントリスナー
│       ├── config/         Symfony 設定ファイル
│       ├── templates/      Twig テンプレート
│       └── migrations/     データベースマイグレーション
├── Makefile                オーケストレーションコマンド
└── README.md
```
