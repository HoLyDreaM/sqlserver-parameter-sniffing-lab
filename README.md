# SQL Server Parameter Sniffing Lab

**Proje kökü:** `sqlserver-parameter-sniffing-lab/` (`d:\SoftWare\sqlserver-parameter-sniffing-lab`)

SQL Server parameter sniffing, Query Store ve SQL Server 2022 Parameter Sensitive Plan (PSP) optimizasyonunu **ölçülebilir** şekilde denemek için laboratuvar. Amaç sniffing'i kapatmak değil; aynı sorgunun farklı parametrelerde nasıl davrandığını görmek, sonra en dar çözümü seçmektir.

> Bu depo bir **demo / öğrenme** ortamıdır. Üretim veritabanına doğrudan uygulanmamalıdır.

## Proje amacı

- Dengesiz `CustomerId` dağılımında tek planın yeniden kullanımını göstermek
- Küçük müşteri (20 satır) ile balina müşteri (80.000 satır) arasında logical reads, CPU ve süre karşılaştırması
- Query Store ile aynı `query_id` altındaki planları okumak
- İstatistik histogramında skew'i görmek
- PSP, `RECOMPILE`, `OPTIMIZE FOR` ve Query Store hint seçeneklerini ayrı ayrı ölçmek

Makaledeki 20 satıra karşı 2 milyon satır örneği burada Docker'a sığacak şekilde ölçeklenmiştir: oran yaklaşık **4.000 : 1** (20'ye karşı 80.000). Mutlak satır sayısı değil, dağılım farkı planı değiştirir.

## Kurulum

### Önkoşullar

- Docker Desktop (veya uyumlu runtime)
- `sqlcmd`, Azure Data Studio veya SSMS
- `sqlcmd` örneklerinde `-I` ve `-f 65001` vardır. Şema betiği `QUOTED_IDENTIFIER` oturumunu da açar; XML plan okuması bu ayar olmadan hata verir.
- SQL Server 2022 (`docker-compose.yml`). PSP için veritabanı compatibility level **160**

### Ortam dosyası ve güvenlik

```powershell
cd d:\SoftWare\sqlserver-parameter-sniffing-lab
copy .env.example .env
```

- **Şifreleri repoya yazmayın** — yalnızca `.env` (gitignore).
- `.env.example` içindeki `MSSQL_SA_PASSWORD=YourStrong!Passw0rd` **örnek / varsayılandır**. Laboratuvar dışında kullanmayın; kendi güçlü SA şifrenizi `.env` içinde tanımlayın.
- Port yayını **yalnızca localhost**: `127.0.0.1:${MSSQL_HOST_PORT}:1433` — LAN'a açık değildir.
- Varsayılan host portu **14335** (yerel `1433` ve diğer lab'lerle çakışmasın diye).

### PowerShell script'leri

```powershell
cd d:\SoftWare\sqlserver-parameter-sniffing-lab
.\scripts\setup.ps1
.\scripts\run-lab.ps1
```

`setup.ps1` yoksa `.env` kopyalar ve container'ı ayağa kaldırır. `run-lab.ps1` healthy olmasını bekler ve sqlcmd sırasını yazar.

Durdurma: `docker compose down`. Veri volume'unu silmek için `docker compose down -v`.

### Veritabanı bootstrap (sıra önemli)

`<port>` = `.env` içindeki `MSSQL_HOST_PORT` (varsayılan `14335`):

```bash
sqlcmd -S localhost,<port> -U sa -P "<sifre>" -C -I -f 65001 -i database/01-create-database.sql
sqlcmd -S localhost,<port> -U sa -P "<sifre>" -C -I -f 65001 -d SniffLab -i database/02-create-schema.sql
sqlcmd -S localhost,<port> -U sa -P "<sifre>" -C -I -f 65001 -d SniffLab -i database/03-seed-data.sql
sqlcmd -S localhost,<port> -U sa -P "<sifre>" -C -I -f 65001 -d SniffLab -i database/04-enable-query-store.sql
sqlcmd -S localhost,<port> -U sa -P "<sifre>" -C -I -f 65001 -i scripts/run-smoke-tests.sql
```

Seed ilk çalıştırmada kısa sürer. `04-enable-query-store.sql` bu veritabanının Query Store geçmişini temizler; lab ortasında tekrarlamayın.

## Domain modeli

| Nesne | Rol |
|-------|-----|
| `Customers` | `W` = balina (`CustomerId = 1`), `S` = küçük müşteri |
| `Orders` | Siparişler. `Note` dar indekste olmadığı için Key Lookup oluşur |
| `IX_Orders_CustomerId` | Bilerek covering değil |
| `dbo.usp_GetOrdersByCustomer` | Hint'siz asıl prosedür |
| `*_Recompile`, `*_OptimizeForWhale`, `*_OptimizeForUnknown` | Yalnız lab 06 |
| `LabMeasurement` | Script'lerin yazdığı ölçüm satırları |
| `SeedMeta` | Balina / küçük müşteri kimlikleri |

Lab script'leri sonuçları `dbo.LabMeasurement` tablosuna yazar. `dbo.usp_GetOrdersByCustomer` sipariş kolonlarını okur (bu yüzden dar indeks Key Lookup üretir) ve istemciye tek satır döner: satır sayısı ile bir checksum. Böylece logical reads, 80.000 satırı tempdb'ye taşımanın maliyetiyle karışmaz.

SSMS'te Actual Execution Plan için aynı `WHERE CustomerId = @CustomerId` şeklindeki `SELECT` yeterlidir. Balina satırlarını grid'e dökmeyin.

## Lab listesi

| # | Klasör | Ne gösterir? |
|---|--------|----------------|
| 01 | `labs/01-parameter-sniffing-nedir` | Sniffing'in plan yeniden kullanımı olduğunu ve skew oranını |
| 02 | `labs/02-belirtiyi-yakala` | Önce küçük, sonra balina (ve tersi) — aynı planın maliyeti |
| 03 | `labs/03-plan-ve-query-store` | Oturum ölçümü + Query Store plan / runtime istatistikleri |
| 04 | `labs/04-dagilim-ve-istatistik` | Histogram (`EQ_ROWS`) ve istatistik tarihi |
| 05 | `labs/05-psp-optimization` | Compatibility 160, dispatcher ve query variant |
| 06 | `labs/06-recompile-ve-optimize-for` | `RECOMPILE`, `OPTIMIZE FOR`, `OPTIMIZE FOR UNKNOWN` |
| 07 | `labs/07-query-store-hints` | Kod değiştirmeden `OPTION (OPTIMIZE FOR UNKNOWN)` |

Örnek:

```bash
sqlcmd -S localhost,<port> -U sa -P "<sifre>" -C -I -f 65001 -d SniffLab -i labs/02-belirtiyi-yakala/small-then-whale.sql
sqlcmd -S localhost,<port> -U sa -P "<sifre>" -C -I -f 65001 -d SniffLab -i labs/02-belirtiyi-yakala/whale-then-small.sql
```

Lab 02, PSP'yi **kapatır**. Böylece SQL Server 2022 tek planı kendiliğinden çoğaltmaz ve belirti görünür. Lab 05 PSP'yi tekrar açar. Karışık çalıştırdıysanız:

```bash
sqlcmd -S localhost,<port> -U sa -P "<sifre>" -C -I -f 65001 -d SniffLab -i scripts/reset-lab-state.sql
```

`reset-lab-state.sql` veriyi silmez. PSP'yi kapatır ve temel prosedürdeki Query Store hint'ini temizler. `sp_recompile` yalnız bu laboratuvar prosedürlerini işaretler; instance plan cache'ini boşaltmaz.

Lab 07 hint'i **siz temizleyene kadar** `SniffLab` içinde kalır. Bitince `labs/07-query-store-hints/clear-hint.sql` çalıştırın.

## Ölçüm tablosu (kullanıcı doldurur)

Sabit yüzde iddiası yoktur. `LabMeasurement` çıktısındaki değerleri buraya yazın.

| Lab | Senaryo | Logical reads | CPU ms | Elapsed ms | Plan notu |
|-----|---------|---------------|--------|------------|-----------|
| 02 | Küçük, sonra balina (aynı plan) | | | | |
| 02 | Balina, sonra küçük (aynı plan) | | | | |
| 05 | PSP açık, iki müşteri | | | | |
| 06 | RECOMPILE | | | | |
| 06 | OPTIMIZE FOR (balina) | | | | |
| 06 | OPTIMIZE FOR UNKNOWN | | | | |
| 07 | Query Store hint sonrası | | | | |

Lab 02'de küçük müşteriyle derlenen seek planı balinada kalırsa logical reads'in belirgin sıçraması beklenir. Tersi yönde scan planı küçük çağrıda da kullanılabilir. Donanım ve buffer pool sonucu değiştirir.

## PSP notu

PSP, eşitlik parametresi ve çarpık histogram gördüğünde bir dispatcher plan ile birden fazla varyant tutabilir. Query variant runtime istatistikleri `sys.query_store_query_variant` üzerinden okunur; dispatcher planının kendisi runtime üretmez.

Varyant satırı gelmezse özellik "bozuk" demek değildir. Compatibility 160, `PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = ON` ve predicate şekli eligibility'yi belirler. O durumda lab 06 ve 07 hedefli araçlardır.

`OPTIMIZE FOR (@degisken = literal)` bir Query Store hint'i **değildir**. Lab 07 bu yüzden `OPTION (OPTIMIZE FOR UNKNOWN)` kullanır. `OPTIMIZE FOR (1)` karşılaştırması lab 06'daki prosedür içindedir ve seed sözleşmesine bağlıdır: balina `CustomerId = 1`.

## Production notları

- Demo sonucu üretim SLA'sı değildir.
- Sniffing'i sistem genelinde kapatmak bu laboratuvarın önerisi değildir.
- `RECOMPILE` derleme CPU'sunu artırır; sık çalışan kısa sorgunun varsayılanı yapılmamalıdır.
- `OPTIMIZE FOR` bir sihirli hint değildir. Küçük ve büyük parametre sınıflarının **toplam** maliyetini ölçün.
- Query Store hint'leri kod değiştirmeden müdahale içindir ve son çaredir. İş bitince kaldırın.
- `DBCC FREEPROCCACHE` ve `DBCC DROPCLEANBUFFERS` paylaşımlı veya üretim instance'ta çalıştırılmaz. Script'ler bunları çağırmaz.

## Dosya yapısı

```text
sqlserver-parameter-sniffing-lab/
├── database/
│   ├── 01-create-database.sql
│   ├── 02-create-schema.sql
│   ├── 03-seed-data.sql
│   └── 04-enable-query-store.sql
├── labs/
│   ├── 01-parameter-sniffing-nedir/
│   ├── 02-belirtiyi-yakala/
│   ├── 03-plan-ve-query-store/
│   ├── 04-dagilim-ve-istatistik/
│   ├── 05-psp-optimization/
│   ├── 06-recompile-ve-optimize-for/
│   └── 07-query-store-hints/
├── scripts/
│   ├── setup.ps1
│   ├── run-lab.ps1
│   ├── reset-lab-state.sql
│   └── run-smoke-tests.sql
├── docker/
│   └── wait-healthy.sh
├── docker-compose.yml
├── .env.example
├── .gitignore
├── LICENSE
├── CHANGELOG.md
└── README.md
```

## Kaynaklar

- [Query processing architecture guide](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)
- [Parameter Sensitive Plan optimization](https://learn.microsoft.com/en-us/sql/relational-databases/performance/parameter-sensitive-plan-optimization)
- [Query Store hints](https://learn.microsoft.com/en-us/sql/relational-databases/performance/query-store-hints)
- [Tune performance with the Query Store](https://learn.microsoft.com/en-us/sql/relational-databases/performance/tune-performance-with-the-query-store)

## İlgili Makale

[SQL Server Parameter Sniffing: 7 Adımda Plan Sorunlarını Çözme](https://www.mehmet-ozdemir.com.tr/sql-server-parameter-sniffing/)

## Yazar

Mehmet Özdemir | https://www.mehmet-ozdemir.com.tr/

## Lisans

MIT — bkz. `LICENSE`.
