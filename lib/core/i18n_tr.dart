// Turkish UI strings. Keys are the English source text (see i18n.dart).
// Missing keys fall back to English.

const Map<String, String> trTable = {
  // --- General
  'Cancel': 'İptal',
  'Save': 'Kaydet',
  'Done': 'Tamam',
  'Close': 'Kapat',
  'Close (Esc)': 'Kapat (Esc)',
  'Delete': 'Sil',
  'Delete…': 'Sil…',
  'Edit': 'Düzenle',
  'Remove': 'Kaldır',
  'Rename': 'Yeniden adlandır',
  'Rename…': 'Yeniden adlandır…',
  'Open': 'Aç',
  'Copy': 'Kopyala',
  'Move': 'Taşı',
  'Move / copy': 'Taşı / kopyala',
  'Move / copy…': 'Taşı / kopyala…',
  'Refresh': 'Yenile',
  'Refresh (F5)': 'Yenile (F5)',
  'Reload': 'Yeniden yükle',
  'Try again': 'Tekrar dene',
  'Back': 'Geri',
  'Clear': 'Temizle',
  'Create': 'Oluştur',
  'Details': 'Ayrıntılar',
  'Dismiss': 'Kapat',
  'Hide': 'Gizle',
  'Manage': 'Yönet',
  'View all': 'Tümünü gör',
  'All': 'Tümü',
  'Name': 'Ad',
  'Name (optional)': 'Ad (isteğe bağlı)',
  'Label (optional)': 'Etiket (isteğe bağlı)',
  'Status': 'Durum',
  'Version': 'Sürüm',
  'Size': 'Boyut',
  'Type': 'Tür',
  'Type ': 'Onaylamak için ',
  ' to confirm.': ' yazın.',
  'Modified': 'Değiştirilme',
  'Created': 'Oluşturulma',
  'Key': 'Anahtar',
  'Key copied': 'Anahtar kopyalandı',
  'Link': 'Bağlantı',
  'Prefix': 'Önek',
  'Prefix ': 'Önek ',
  'Prefix copied': 'Önek kopyalandı',
  'Disabled': 'Kapalı',
  'Active': 'Etkin',
  'Current': 'Güncel',
  'Unlimited': 'Sınırsız',
  'Nothing found': 'Bir şey bulunamadı',
  'days': 'gün',
  'key': 'anahtar',
  'value': 'değer',
  'Paused': 'Duraklatıldı',
  'Follow': 'Takip et',
  'up to date': 'güncel',
  'You': 'Siz',
  'This app': 'Bu uygulama',
  'Offline': 'Çevrimdışı',
  'Connected': 'Bağlı',
  'Switch to': 'Geçiş yap',
  'Text copied': 'Metin kopyalandı',

  // --- Shell & navigation
  'Dashboard': 'Pano',
  'Buckets': 'Bucket\'lar',
  'Server': 'Sunucu',
  'App': 'Uygulama',
  'Admin users': 'Yönetici kullanıcılar',
  'Sessions': 'Oturumlar',
  'Activity log': 'Etkinlik günlüğü',
  'Metrics': 'Metrikler',
  'Maintenance': 'Bakım',
  'Configuration': 'Yapılandırma',
  'All servers': 'Tüm sunucular',
  'Settings': 'Ayarlar',
  'Overview': 'Genel bakış',
  'Files': 'Dosyalar',
  'Access keys': 'Erişim anahtarları',
  'Lifecycle': 'Yaşam döngüsü',
  'Webhooks': 'Webhook\'lar',
  'Close bucket': 'Bucket\'ı kapat',
  'All buckets': 'Tüm bucket\'lar',
  'Disconnect': 'Bağlantıyı kes',
  'Add server…': 'Sunucu ekle…',
  'Edit this server…': 'Bu sunucuyu düzenle…',
  'Transfers': 'Aktarımlar',
  'Cancel all': 'Tümünü iptal et',
  'No transfers': 'Aktarım yok',
  'Show in folder': 'Klasörde göster',

  // --- Welcome / servers
  'Add server': 'Sunucu ekle',
  'Add another server': 'Başka sunucu ekle',
  'Remove server': 'Sunucuyu kaldır',
  'Connect to a Cloodsy S3 Admin API endpoint.':
      'Bir Cloodsy S3 Admin API adresine bağlanın.',
  'Admin API URL': 'Admin API adresi',
  'Use https:// when admin TLS is enabled':
      'Admin TLS açıksa https:// kullanın',
  'Display name': 'Görünen ad',
  'Production (defaults to the host)': 'Üretim (boşsa sunucu adresi)',
  'Username': 'Kullanıcı adı',
  'Password': 'Şifre',
  'The password is stored in the system keychain.':
      'Şifre sistemin anahtar zincirinde saklanır.',
  'Advanced': 'Gelişmiş',
  'Public S3 endpoint (optional)': 'Genel S3 adresi (isteğe bağlı)',
  'Used for share links. Default: admin host + S3 port':
      'Paylaşım bağlantılarında kullanılır. Varsayılan: admin sunucusu + S3 portu',
  'Every saved server at a glance.': 'Kayıtlı tüm sunucular tek bakışta.',

  // --- Dashboard
  'Largest buckets': 'En büyük bucket\'lar',
  'No buckets yet': 'Henüz bucket yok',
  'Create a bucket to start storing objects.':
      'Nesne saklamaya başlamak için bir bucket oluşturun.',
  'New bucket': 'Yeni bucket',
  'Objects': 'Nesneler',
  'across all buckets': 'tüm bucket\'larda',
  'Stored': 'Depolanan',
  'latest object versions': 'nesnelerin güncel sürümleri',
  'Disk': 'Disk',
  'Uptime': 'Çalışma süresi',
  'S3 TLS': 'S3 TLS',
  'Admin TLS': 'Admin TLS',
  'Certificates': 'Sertifikalar',
  'WebDAV': 'WebDAV',
  'Data directory': 'Veri dizini',
  'This server predates file upload/download in the admin API. Update the server to browse, upload and download objects here.':
      'Bu sunucu, admin API\'ye dosya yükleme/indirme eklenmeden önceki bir sürüm. Nesneleri buradan yüklemek ve indirmek için sunucuyu güncelleyin.',
  '{n} objects': '{n} nesne',

  // --- Buckets
  'Filter buckets': 'Bucket filtrele',
  'No matching buckets': 'Eşleşen bucket yok',
  'Buckets hold your objects. Create one, then add an access key to use it from any S3 client.':
      'Bucket\'lar nesnelerinizi tutar. Bir tane oluşturun, ardından herhangi bir S3 istemcisinden kullanmak için erişim anahtarı ekleyin.',
  'Create bucket': 'Bucket oluştur',
  'Bucket name': 'Bucket adı',
  'Lowercase letters, digits and hyphens':
      'Küçük harf, rakam ve tire',
  'Custom storage directory': 'Özel depolama dizini',
  'Store this bucket outside the default data dir':
      'Bu bucket\'ı varsayılan veri dizininin dışında sakla',
  'Absolute path on the server': 'Sunucudaki tam yol',
  'Delete bucket': 'Bucket\'ı sil',
  'Delete bucket…': 'Bucket\'ı sil…',
  'Bucket is not empty': 'Bucket boş değil',
  'Delete anyway removes every object, all versions and delete markers together with the bucket. This cannot be undone.':
      'Yine de silmek, bucket ile birlikte tüm nesneleri, sürümleri ve silme işaretlerini kaldırır. Geri alınamaz.',
  'Delete everything': 'Her şeyi sil',
  'Versioned': 'Sürümlü',
  'Public': 'Herkese açık',
  'Custom storage': 'Özel depolama',

  // --- Bucket overview
  'Usage': 'Kullanım',
  'Rules': 'Kurallar',
  'Access': 'Erişim',
  'Bucket': 'Bucket',
  'Connect': 'Bağlan',
  'Use any S3 SDK, rclone, s3cmd or the Cloodsy app.':
      'Herhangi bir S3 SDK\'sı, rclone, s3cmd veya Cloodsy uygulamasını kullanın.',
  'WebDAV mount': 'WebDAV bağlantısı',
  'Sign in with an access key of this bucket as username and its secret key as password.':
      'Kullanıcı adı olarak bu bucket\'ın erişim anahtarını, şifre olarak gizli anahtarını kullanın.',
  'No access keys yet. Create one to connect clients.':
      'Henüz erişim anahtarı yok. İstemcileri bağlamak için bir tane oluşturun.',
  'Create key': 'Anahtar oluştur',
  'Storage': 'Depolama',

  // --- Files
  'Upload': 'Yükle',
  'Upload files': 'Dosya yükle',
  'Upload files…': 'Dosya yükle…',
  'Upload folder…': 'Klasör yükle…',
  'New folder': 'Yeni klasör',
  'Folder name': 'Klasör adı',
  'Size of this folder': 'Bu klasörün boyutu',
  'Calculate size': 'Boyutu hesapla',
  'Copy prefix': 'Öneki kopyala',
  'Delete folder': 'Klasörü sil',
  'Delete folder…': 'Klasörü sil…',
  'Delete object': 'Nesneyi sil',
  'Permanently delete the selected objects including all of their versions?':
      'Seçili nesneler tüm sürümleriyle birlikte kalıcı olarak silinsin mi?',
  'Drop to upload': 'Yüklemek için bırakın',
  'Back to folder': 'Klasöre dön',
  'Download': 'İndir',
  'Download here': 'Buraya indir',
  'Share': 'Paylaş',
  'Share link': 'Paylaşım bağlantısı',
  'Share link…': 'Paylaşım bağlantısı…',
  'Edit metadata': 'Metadata düzenle',
  'Edit metadata…': 'Metadata düzenle…',
  'Metadata': 'Metadata',
  'Metadata saved': 'Metadata kaydedildi',
  'Versions': 'Sürümler',
  'Versions…': 'Sürümler…',
  'Copy key': 'Anahtarı kopyala',
  'Actions': 'İşlemler',
  'Upload and download need Cloodsy S3 with the object API (newer than this server). Browsing and deleting still work.':
      'Yükleme ve indirme, nesne API\'si olan daha yeni bir Cloodsy S3 gerektirir. Gezinme ve silme çalışmaya devam eder.',
  'Object': 'Nesne',
  'On disk': 'Diskte',
  'File': 'Dosya',
  'S3 URI': 'S3 URI',
  'ETag': 'ETag',
  'Update the server to see where this object is stored.':
      'Bu nesnenin nerede saklandığını görmek için sunucuyu güncelleyin.',
  'No file (the current version is a delete marker).':
      'Dosya yok (güncel sürüm bir silme işareti).',
  'Copy local path': 'Yerel yolu kopyala',
  'Local path copied': 'Yerel yol kopyalandı',
  'Could not open the file manager': 'Dosya yöneticisi açılamadı',
  'Open with default app': 'Varsayılan uygulamayla aç',
  'Not a decodable image': 'Görsel okunamadı',

  // --- Versions
  'Delete version': 'Sürümü sil',
  'Download this version': 'Bu sürümü indir',
  'Copy version id': 'Sürüm kimliğini kopyala',
  'Version id copied': 'Sürüm kimliği kopyalandı',
  'Delete marker': 'Silme işareti',
  'No versions recorded.': 'Kayıtlı sürüm yok.',

  // --- Share
  'Expiring link': 'Süreli bağlantı',
  'Public URL': 'Herkese açık URL',
  'Public URLs need “Public read” on the bucket.':
      'Herkese açık URL için bucket\'ta “Herkese açık okuma” açık olmalı.',
  'Sign with key': 'İmzalayan anahtar',
  'Expires in': 'Geçerlilik',
  'This bucket has no access key yet. Create one under “Access keys” to sign links.':
      'Bu bucket\'ın henüz erişim anahtarı yok. Bağlantı imzalamak için “Erişim anahtarları” altında bir tane oluşturun.',
  'Signed with a read & write key. The link only allows downloading this object, but a read-only key is safer.':
      'Okuma-yazma anahtarıyla imzalandı. Bağlantı yalnızca bu nesneyi indirmeye izin verir ama salt okunur anahtar daha güvenlidir.',
  'S3 endpoint': 'S3 adresi',
  'The address clients use to reach the S3 API':
      'İstemcilerin S3 API\'ye ulaştığı adres',
  'Image resize (optional)': 'Görsel boyutlandırma (isteğe bağlı)',
  'Enter a valid S3 endpoint to build the link.':
      'Bağlantıyı oluşturmak için geçerli bir S3 adresi girin.',

  // --- Move / metadata dialogs
  'Destination bucket': 'Hedef bucket',
  'Content-Type': 'Content-Type',
  'User metadata (x-amz-meta-*)': 'Kullanıcı metadata\'sı (x-amz-meta-*)',
  'Add field': 'Alan ekle',
  'The bucket is versioned: saving creates a new version of the object with the same content.':
      'Bucket sürümlü: kaydetmek, aynı içerikle nesnenin yeni bir sürümünü oluşturur.',

  // --- Access keys
  'Access keys authenticate S3 clients (SigV4) and WebDAV mounts for this bucket only.':
      'Erişim anahtarları S3 istemcilerinin (SigV4) ve WebDAV bağlantılarının yalnızca bu bucket için kimliğini doğrular.',
  'New access key': 'Yeni erişim anahtarı',
  'No access keys': 'Erişim anahtarı yok',
  'Create a key to connect an S3 SDK, rclone or the Cloodsy app to this bucket.':
      'Bu bucket\'a S3 SDK\'sı, rclone veya Cloodsy uygulaması bağlamak için bir anahtar oluşturun.',
  'Create access key': 'Erişim anahtarı oluştur',
  'Access key': 'Erişim anahtarı',
  'Secret key': 'Gizli anahtar',
  'Access key created': 'Erişim anahtarı oluşturuldu',
  'Use these with any S3 SDK or client. You can view the secret again later from this list.':
      'Bunları herhangi bir S3 SDK\'sı veya istemcisiyle kullanın. Gizli anahtarı daha sonra bu listeden yeniden görebilirsiniz.',
  'Permission': 'Yetki',
  'Read & write': 'Okuma ve yazma',
  'Read only': 'Salt okunur',
  'e.g. Backend service': 'ör. Arka uç servisi',
  'Revoke': 'İptal et',
  'Revoke key': 'Anahtarı iptal et',
  'Revoke access key': 'Erişim anahtarını iptal et',
  'Clients using this key lose access immediately.':
      'Bu anahtarı kullanan istemciler erişimi hemen kaybeder.',

  // --- Bucket settings
  'Access & features': 'Erişim ve özellikler',
  'Versioning': 'Sürümleme',
  'Public read': 'Herkese açık okuma',
  'WebDAV access': 'WebDAV erişimi',
  'Quota': 'Kota',
  'Storage quota': 'Depolama kotası',
  'Uploads that would exceed the quota are rejected.':
      'Kotayı aşacak yüklemeler reddedilir.',
  'Remove quota': 'Kotayı kaldır',
  'Storage directory': 'Depolama dizini',
  'Existing objects are moved to the new location. Large buckets can take a while; the bucket is locked meanwhile.':
      'Mevcut nesneler yeni konuma taşınır. Büyük bucket\'larda bu biraz sürebilir; bu sırada bucket kilitlenir.',
  'Leave empty for the default directory': 'Varsayılan dizin için boş bırakın',
  'Move data': 'Veriyi taşı',
  'Moving…': 'Taşınıyor…',
  'Image variants': 'Görsel varyantları',
  'Regenerate optimized image variants for every object (runs in the background).':
      'Tüm nesneler için optimize görsel varyantlarını yeniden üret (arka planda çalışır).',
  'Reprocessing started': 'Yeniden işleme başladı',
  'Removes the bucket and its access keys, rules and webhooks.':
      'Bucket\'ı erişim anahtarları, kuralları ve webhook\'larıyla birlikte kaldırır.',
  'Incomplete uploads': 'Yarım kalan yüklemeler',
  'None. Every multipart upload was completed or cleaned up.':
      'Yok. Tüm çok parçalı yüklemeler tamamlanmış veya temizlenmiş.',
  'Abort': 'İptal et',
  'Abort all': 'Tümünü iptal et',
  'Abort older than 7 days': '7 günden eskileri iptal et',
  'Abort uploads': 'Yüklemeleri iptal et',

  // --- Lifecycle
  'Lifecycle rules expire objects, prune old versions and clean up abandoned uploads automatically.':
      'Yaşam döngüsü kuralları nesneleri otomatik olarak sona erdirir, eski sürümleri budar ve yarım kalan yüklemeleri temizler.',
  'Add rule': 'Kural ekle',
  'Remove all': 'Tümünü kaldır',
  'Remove all rules': 'Tüm kuralları kaldır',
  'Delete every lifecycle rule of this bucket?':
      'Bu bucket\'ın tüm yaşam döngüsü kuralları silinsin mi?',
  'No lifecycle rules': 'Yaşam döngüsü kuralı yok',
  'Add a rule to clean up logs, temporary uploads, old versions or backups after a number of days.':
      'Günlükleri, geçici yüklemeleri, eski sürümleri veya yedekleri belirli bir süre sonra temizlemek için kural ekleyin.',
  'Delete rule': 'Kuralı sil',
  'All objects': 'Tüm nesneler',
  'Rules run periodically on the server.':
      'Kurallar sunucuda düzenli aralıklarla çalışır.',
  'Expiration rule': 'Sona erme kuralı',
  'Objects older than the given age are deleted automatically.':
      'Belirtilen yaştan eski nesneler otomatik olarak silinir.',
  'Expire after': 'Sona erme',
  'Empty applies to every object': 'Boşsa tüm nesnelere uygulanır',
  'logs/ (empty = all)': 'logs/ (boş = tümü)',
  'Log cleanup': 'Günlük temizliği',
  'e.g. Log cleanup': 'ör. Günlük temizliği',
  'Expire objects': 'Nesneleri sona erdir',
  'Delete old versions': 'Eski sürümleri sil',
  'Abort incomplete uploads': 'Yarım kalan yüklemeleri iptal et',
  'Frees space held by multipart uploads that never finished':
      'Hiç tamamlanmamış çok parçalı yüklemelerin tuttuğu alanı boşaltır',
  'Remove orphan delete markers': 'Sahipsiz silme işaretlerini kaldır',
  'Delete markers with no versions left behind them':
      'Arkasında hiç sürüm kalmamış silme işaretleri',
  'Rule enabled': 'Kural etkin',

  // --- Webhooks
  'Webhooks notify your services when objects are created or removed in this bucket.':
      'Webhook\'lar, bu bucket\'ta nesne oluşturulduğunda veya silindiğinde servislerinizi haberdar eder.',
  'Add webhook': 'Webhook ekle',
  'No webhooks': 'Webhook yok',
  'Send object events to a URL, e.g. to trigger thumbnails, indexing or notifications.':
      'Nesne olaylarını bir URL\'ye gönderin; ör. küçük resim, indeksleme veya bildirim tetiklemek için.',
  'The server POSTs a JSON event to this URL.':
      'Sunucu bu URL\'ye JSON olayı POST eder.',
  'Endpoint URL': 'Hedef URL',
  'Signing secret (optional)': 'İmza anahtarı (isteğe bağlı)',
  'Events': 'Olaylar',
  'All events': 'Tüm olaylar',
  'Inactive webhooks receive no events': 'Pasif webhook\'lar olay almaz',
  'Signed': 'İmzalı',
  'Send a test event': 'Test olayı gönder',
  'Delivery history': 'Teslim geçmişi',
  'Deliveries': 'Teslimler',
  'No deliveries yet. Use “Send a test event” to try it.':
      'Henüz teslim yok. Denemek için “Test olayı gönder”i kullanın.',
  'Delete webhook': 'Webhook\'u sil',
  'Stop sending events to this URL?': 'Bu URL\'ye olay gönderimi durdurulsun mu?',

  // --- Admins & sessions
  'Accounts that can sign in to this server’s Admin API.':
      'Bu sunucunun Admin API\'sine giriş yapabilen hesaplar.',
  'Add admin': 'Yönetici ekle',
  'Delete admin': 'Yöneticiyi sil',
  'Generate a strong password': 'Güçlü bir şifre üret',
  '8+ characters, max 72 bytes': 'En az 8 karakter, en fazla 72 bayt',
  'Copy this password now. It will not be shown again.':
      'Bu şifreyi şimdi kopyalayın. Bir daha gösterilmeyecek.',
  'Admin API sign-ins on this server.': 'Bu sunucudaki Admin API girişleri.',
  'End': 'Sonlandır',
  'End session': 'Oturumu sonlandır',

  // --- Logs / metrics / maintenance / config
  'Info+': 'Bilgi+',
  'Warn+': 'Uyarı+',
  'Errors': 'Hatalar',
  'Search log': 'Günlükte ara',
  'Copy visible lines': 'Görünen satırları kopyala',
  'Clear view': 'Görünümü temizle',
  'No log lines yet': 'Henüz günlük satırı yok',
  'Requests': 'İstekler',
  'Uploaded': 'Yüklenen',
  'Downloaded': 'İndirilen',
  'Per minute, last 60 minutes': 'Dakika başına, son 60 dakika',
  'Check that the database and the files on disk agree.':
      'Veritabanı ile diskteki dosyaların tutarlı olup olmadığını denetleyin.',
  'No scan yet': 'Henüz tarama yok',
  'The scan is read-only. It lists leftover bucket folders, objects whose file is missing and files no object points to.':
      'Tarama salt okunurdur. Artık bucket klasörlerini, dosyası kayıp nesneleri ve hiçbir nesnenin göstermediği dosyaları listeler.',
  'Orphan folders': 'Sahipsiz klasörler',
  'Missing files': 'Kayıp dosyalar',
  'Untracked files': 'İzlenmeyen dosyalar',
  'Delete all…': 'Tümünü sil…',
  'Delete orphan folders': 'Sahipsiz klasörleri sil',
  'Effective server settings (read-only, secrets masked). Change them in config.yaml on the server and restart it.':
      'Geçerli sunucu ayarları (salt okunur, gizli değerler maskeli). Değiştirmek için sunucudaki config.yaml\'ı düzenleyip sunucuyu yeniden başlatın.',
  'Copy JSON': 'JSON olarak kopyala',
  'Configuration copied as JSON': 'Yapılandırma JSON olarak kopyalandı',

  // --- Settings
  'Appearance': 'Görünüm',
  'Theme': 'Tema',
  'Light': 'Açık',
  'Dark': 'Koyu',
  'System': 'Sistem',
  'Language': 'Dil',
  'Notify when transfers finish': 'Aktarımlar bitince bildir',
  'System notification after a batch of uploads or downloads':
      'Bir grup yükleme veya indirme bitince sistem bildirimi',
  'Download folder': 'İndirme klasörü',
  'Asks every time': 'Her seferinde sorar',
  'The last folder you saved to is suggested next time':
      'Son kaydettiğiniz klasör bir dahaki sefere önerilir',
  'Connection': 'Bağlantı',
  'Signed in as': 'Giriş yapan',
  'Session': 'Oturum',
  'Renews automatically · current token valid until {t}':
      'Otomatik yenilenir · mevcut belirteç {t} tarihine kadar geçerli',
  'Server version': 'Sunucu sürümü',
  'Keyboard shortcuts': 'Klavye kısayolları',
  'Command palette: jump to any page, bucket or action':
      'Komut paleti: herhangi bir sayfaya, bucket\'a veya işleme atla',
  'Search files': 'Dosyalarda ara',
  'Select all files in the folder': 'Klasördeki tüm dosyaları seç',
  'Move between files / select': 'Dosyalar arasında gezin / seç',
  'Download the highlighted file': 'Vurgulanan dosyayı indir',
  'Delete selected files': 'Seçili dosyaları sil',
  'Up one folder': 'Bir üst klasör',
  'Clear selection / close details': 'Seçimi temizle / ayrıntıları kapat',
  'About': 'Hakkında',
  'Check for updates': 'Güncellemeleri denetle',
  'Licenses': 'Lisanslar',
  'Cloodsy S3 GUI {v} is available (you have {c}).':
      'Cloodsy S3 GUI {v} yayınlandı (sizdeki: {c}).',

  // --- Hand-written tr() calls in widgets and controllers
  'Choose a server to connect to.': 'Bağlanılacak sunucuyu seçin.',
  'Add your first server to start managing buckets.':
      'Bucket yönetmeye başlamak için ilk sunucunuzu ekleyin.',
  'Session expired. Please reconnect.':
      'Oturumun süresi doldu. Lütfen yeniden bağlanın.',
  'No saved password for this server. Edit it and try again.':
      'Bu sunucu için kayıtlı şifre yok. Düzenleyip tekrar deneyin.',
  '{n} selected': '{n} seçili',
  'Filter · Enter searches all subfolders':
      'Filtrele · Enter tüm alt klasörlerde arar',
  'Filter this folder': 'Bu klasörü filtrele',
  'This folder is empty': 'Bu klasör boş',
  'Drop files or folders here, or use Upload.':
      'Dosya veya klasörleri buraya bırakın ya da Yükle\'yi kullanın.',
  'Use Upload to add files.': 'Dosya eklemek için Yükle\'yi kullanın.',
  'Press Enter to search all subfolders.':
      'Tüm alt klasörlerde aramak için Enter\'a basın.',
  'Load more': 'Daha fazla yükle',
  'Loading…': 'Yükleniyor…',
  'Online': 'Çevrimiçi',
  'Connecting…': 'Bağlanıyor…',
  'Renews {t}': '{t} yenilenir',
  'Signed in': 'Giriş yapıldı',
  'Something went wrong': 'Bir şeyler ters gitti',
  'Server unreachable': 'Sunucuya ulaşılamıyor',
  'Show': 'Göster',
  '{label} copied': '{label} kopyalandı',
  'Waiting': 'Bekliyor',
  'Saved': 'Kaydedildi',
  'Cancelled': 'İptal edildi',
  'Failed': 'Başarısız',
  'Retry': 'Tekrar dene',
  'Theme: {mode} (right-click for options)':
      'Tema: {mode} (seçenekler için sağ tık)',
  'Signed in as {user}': '{user} olarak giriş yapıldı',
  'Last refresh failed: {e}': 'Son yenileme başarısız: {e}',
  'Command palette': 'Komut paleti',
  'Type a page, bucket or action…': 'Bir sayfa, bucket veya işlem yazın…',
  'No matches': 'Eşleşme yok',
  'Go to': 'Git',
  'Open bucket': 'Bucket aç',
  'Toggle light/dark theme': 'Açık/koyu temayı değiştir',
  'Switch to {name}': '{name} sunucusuna geç',
  'Transfers complete': 'Aktarımlar tamamlandı',
  'Transfers finished with errors': 'Aktarımlar hatalarla bitti',

  // --- Templates with placeholders
  'Abort every incomplete upload in this bucket? Clients still uploading will fail.':
      'Bu bucket\'taki tüm yarım yüklemeler iptal edilsin mi? Hâlâ yükleme yapan istemciler hata alır.',
  'Abort incomplete uploads after {n} days': 'Yarım yüklemeleri {n} gün sonra iptal et',
  'Abort incomplete uploads started more than {n} days ago?':
      '{n} günden önce başlamış yarım yüklemeler iptal edilsin mi?',
  'Active {a} · signed in {s} · expires {e}':
      'Son etkinlik {a} · giriş {s} · bitiş {e}',
  'Added {d}': '{d} tarihinde eklendi',
  'Adds a delete marker; older versions stay until removed':
      'Silme işareti ekler; eski sürümler kaldırılana kadar kalır',
  'Admin “{u}” deleted': '“{u}” yöneticisi silindi',
  'Admins have full control over every bucket on this server.':
      'Yöneticiler bu sunucudaki tüm bucket\'lar üzerinde tam yetkiye sahiptir.',
  'All {n} objects are consistent with the disk.':
      '{n} nesnenin tamamı diskle tutarlı.',
  'Anyone with the URL can download objects.':
      'URL\'yi bilen herkes nesneleri indirebilir.',
  'At least {n} characters': 'En az {n} karakter',
  'At most {n} bytes (bcrypt limit)': 'En fazla {n} bayt (bcrypt sınırı)',
  'Bucket is busy: {what}': 'Bucket meşgul: {what}',
  'Bucket “{name}” created': '“{name}” bucket\'ı oluşturuldu',
  'Bucket “{name}” deleted': '“{name}” bucket\'ı silindi',
  'Cloodsy S3 v{v} is available (this server runs v{c}). Run "cloodsys3 update" on the server to upgrade.':
      'Cloodsy S3 v{v} yayınlandı (bu sunucu v{c} çalıştırıyor). Güncellemek için sunucuda "cloodsys3 update" çalıştırın.',
  'Copied on the server; nothing is downloaded.':
      'Sunucuda kopyalanır; hiçbir şey indirilmez.',
  'Copied to {dest}': '{dest} konumuna kopyalandı',
  'Moved to {dest}': '{dest} konumuna taşındı',
  'Created {d}': '{d} tarihinde oluşturuldu',
  'Default data directory': 'Varsayılan veri dizini',
  'Delete objects after {n} days': 'Nesneleri {n} gün sonra sil',
  'Delete old versions after {n} days': 'Eski sürümleri {n} gün sonra sil',
  'Delete the bucket “{name}”? The server refuses if it still contains objects.':
      '“{name}” bucket\'ı silinsin mi? İçinde hâlâ nesne varsa sunucu reddeder.',
  'Delete {n} objects': '{n} nesneyi sil',
  'Delete “{name}” and everything inside it? All object versions under this folder are removed.':
      '“{name}” ve içindeki her şey silinsin mi? Bu klasördeki tüm nesne sürümleri kaldırılır.',
  'Delete “{name}”?': '“{name}” silinsin mi?',
  'Delete “{u}”? Their active sessions end immediately.':
      '“{u}” silinsin mi? Aktif oturumları hemen sona erer.',
  'Deletes objects older than': 'Şu süreden eski nesneleri siler',
  'Destination folder (empty = bucket root)': 'Hedef klasör (boş = bucket kökü)',
  'Destination key': 'Hedef anahtar',
  'Enabled': 'Açık',
  'End your own session? You will be disconnected.':
      'Kendi oturumunuz sonlandırılsın mı? Bağlantınız kesilecek.',
  'Every object under “{p}” is processed on the server.':
      '“{p}” altındaki tüm nesneler sunucuda işlenir.',
  'Every overwrite and delete keeps the previous version.':
      'Her üzerine yazma ve silme önceki sürümü korur.',
  'Folder “{name}” created': '“{name}” klasörü oluşturuldu',
  'Folder “{name}” deleted ({n} objects)': '“{name}” klasörü silindi ({n} nesne)',
  'Lists are capped; fix and scan again to see more.':
      'Listeler sınırlı; düzeltip yeniden tarayarak devamını görün.',
  'Live server log (last {n} lines).': 'Canlı sunucu günlüğü (son {n} satır).',
  'Make every object in “{b}” readable without authentication?':
      '“{b}” içindeki tüm nesneler kimlik doğrulaması olmadan okunabilir yapılsın mı?',
  'Metadata keys may only contain letters, digits and “-” ({key})':
      'Metadata anahtarları yalnızca harf, rakam ve “-” içerebilir ({key})',
  'Mountable as a network drive with an access key.':
      'Erişim anahtarıyla ağ sürücüsü olarak bağlanabilir.',
  'Move {what}': '{what} taşı',
  'Copy {what}': '{what} kopyala',
  'Rename {what}': '{what} yeniden adlandır',
  'New name': 'Yeni ad',
  'No objects match “{q}”': '“{q}” ile eşleşen nesne yok',
  'Not mountable over WebDAV.': 'WebDAV ile bağlanamaz.',
  'Nothing matches “{q}”': '“{q}” ile eşleşen bir şey yok',
  'Only relevant for versioned buckets': 'Yalnızca sürümlü bucket\'larda geçerli',
  'Open {tab}': '{tab} aç',
  'Optimized variant · {size}': 'Optimize varyant · {size}',
  'Overwrites and deletes are permanent.': 'Üzerine yazma ve silme kalıcıdır.',
  'Permanently delete this version? This cannot be undone.':
      'Bu sürüm kalıcı olarak silinsin mi? Geri alınamaz.',
  'Permanently delete {n} folder(s) ({size}) from the server disk? The server re-checks each path first.':
      'Sunucu diskinden {n} klasör ({size}) kalıcı olarak silinsin mi? Sunucu her yolu önce yeniden doğrular.',
  'Permanently delete “{name}” including all of its versions?':
      '“{name}” tüm sürümleriyle birlikte kalıcı olarak silinsin mi?',
  'Remove this delete marker? The previous version becomes the current one again.':
      'Bu silme işareti kaldırılsın mı? Önceki sürüm yeniden güncel olur.',
  'Remove “{name}” and its saved password from this computer? The server itself is not affected.':
      '“{name}” ve kayıtlı şifresi bu bilgisayardan kaldırılsın mı? Sunucunun kendisi etkilenmez.',
  'Removes versions this long after they were replaced':
      'Sürümleri, yerlerine yenisi geldikten bu kadar süre sonra kaldırır',
  'Reprocessing is already running': 'Yeniden işleme zaten çalışıyor',
  'Requests must be signed with an access key.':
      'İstekler bir erişim anahtarıyla imzalanmalıdır.',
  'Resume ({n} parts already uploaded)': 'Devam et ({n} parça zaten yüklendi)',
  'Rule #{id}': 'Kural #{id}',
  'Rules without a prefix are removed with “Remove all”':
      'Öneksiz kurallar “Tümünü kaldır” ile silinir',
  'S3 API traffic since {t} (refreshes every 10 s).':
      '{t} tarihinden bu yana S3 API trafiği (10 sn\'de bir yenilenir).',
  'Scanned {n} objects at {t}.': '{t} tarihinde {n} nesne tarandı.',
  'Scoped to the bucket “{b}”.': '“{b}” bucket\'ıyla sınırlı.',
  'Searched every key under /{p}.': '/{p} altındaki tüm anahtarlar arandı.',
  'Set · leave empty to keep': 'Ayarlı · korumak için boş bırakın',
  'Showing the first {size}': 'İlk {size} gösteriliyor',
  'Sign “{u}” out on that device?': '“{u}” o cihazda oturumdan çıkarılsın mı?',
  'Signs “{u}” out of every active session.':
      '“{u}” tüm aktif oturumlarından çıkarılır.',
  'Started {when} · {n} parts · {size}': '{when} başladı · {n} parça · {size}',
  'Suspend versioning? Existing versions are kept, but new overwrites replace the current object.':
      'Sürümleme askıya alınsın mı? Mevcut sürümler korunur ama yeni yazmalar güncel nesnenin yerini alır.',
  'Suspended: existing versions are kept, new writes replace the current object.':
      'Askıda: mevcut sürümler korunur, yeni yazmalar güncel nesnenin yerini alır.',
  'Test delivered: HTTP {code} in {ms} ms': 'Test iletildi: HTTP {code}, {ms} ms',
  'Test failed: {e}': 'Test başarısız: {e}',
  'Too large to preview ({size})': 'Önizleme için çok büyük ({size})',
  'Upload {n} files?': '{n} dosya yüklensin mi?',
  'WebDAV is disabled on this server (webdav.enabled).':
      'Bu sunucuda WebDAV kapalı (webdav.enabled).',
  'Webhook #{id}': 'Webhook #{id}',
  'added {d}': '{d} eklendi',
  'folder': 'klasör',
  'object': 'nesne',
  'into /{p}': '/{p} içine',
  'no quota': 'kota yok',
  'of {size}': '/ {size}',
  'peak {v}': 'en yüksek {v}',
  'read only': 'salt okunur',
  'signed in as {u}': '{u} olarak giriş yapıldı',
  'unknown IP': 'bilinmeyen IP',
  '{done} of {total}': '{done} / {total}',
  '{failed} of {total} could not be deleted': '{total} nesnenin {failed} tanesi silinemedi',
  '{failed} of {total} failed': '{total} işlemin {failed} tanesi başarısız',
  '{free} free of {total}': '{total} alanın {free} kadarı boş',
  '{label} is required': '{label} gerekli',
  '{name}: {n} objects, {size}': '{name}: {n} nesne, {size}',
  '{n} access keys': '{n} erişim anahtarı',
  '{n} access keys can reach this bucket.': '{n} erişim anahtarı bu bucket\'a erişebilir.',
  '{n} active': '{n} etkin',
  '{n} buckets · {size} stored': '{n} bucket · {size} depolanıyor',
  '{n} errors': '{n} hata',
  '{n} files transferred': '{n} dosya aktarıldı',
  '{n} folder(s) deleted': '{n} klasör silindi',
  '{n} lines copied': '{n} satır kopyalandı',
  '{n} objects copied': '{n} nesne kopyalandı',
  '{n} objects deleted': '{n} nesne silindi',
  '{n} objects moved': '{n} nesne taşındı',
  '{n} objects · no quota': '{n} nesne · kota yok',
  '{n} objects · {p}% of {size} quota': '{n} nesne · {size} kotanın %{p}\'i',
  '{n} public': '{n} herkese açık',
  '{n} requests': '{n} istek',
  '{n} results for “{q}” in /{p}': '/{p} içinde “{q}” için {n} sonuç',
  '{n} transfers failed': '{n} aktarım başarısız',
  '{n} transfers running': '{n} aktarım sürüyor',
  '{n} uploads aborted': '{n} yükleme iptal edildi',
  '{n} uploads holding {size}': '{n} yükleme {size} yer tutuyor',
  '{n} versions are kept; see Versions for each file.':
      '{n} sürüm saklanıyor; her dosya için Sürümler\'e bakın.',
  '{ok} deleted, {failed} failed': '{ok} silindi, {failed} başarısız',
  '{ok} deleted, {failed} failed (see server log)':
      '{ok} silindi, {failed} başarısız (sunucu günlüğüne bakın)',
  '{ok} done, {failed} failed': '{ok} tamam, {failed} başarısız',
  '{ok} of {n} recent deliveries succeeded': 'Son {n} teslimin {ok} tanesi başarılı',
  '{ok} succeeded, {failed} failed': '{ok} başarılı, {failed} başarısız',
  '{p}% of {size}': '{size} kotanın %{p}\'i',
  '{size} free': '{size} boş',
  '{used} of {total} used': '{total} alanın {used} kadarı kullanıldı',
  '{what} disabled': '{what} kapatıldı',
  '{what} enabled': '{what} açıldı',
  '“{name}” deleted': '“{name}” silindi',
  '…and {n} more': '…ve {n} tane daha',
  'Search…': 'Ara…',
  'Unreachable': 'Ulaşılamıyor',
};
