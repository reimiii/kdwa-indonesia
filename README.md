# kdwa-indonesia
### Kumpulan Data Wilayah Administratif Indonesia
To install dependencies: --

```bash
bun install
```

---

## Dokumentasi Data Wilayah

### Struktur Data JSON
Setiap file di folder `json` (misal `1.json`, `2.json`, dst) berisi array data wilayah administratif Indonesia dengan struktur:

- `level` (integer):
	- 1 = province (provinsi)
	- 2 = regency and city (kabupaten & kota)
	- 3 = district (kecamatan)
	- 4 = urban village and village (kelurahan & desa)
- `type` (string):
	- province, regency, city, district, urban village, village

### Cara Menggunakan Data
1. Pilih file JSON sesuai level yang diinginkan.
2. Filter data berdasarkan field `level` atau `type` sesuai kebutuhan.

### Contoh Fetch Data JSON dari URL
```ts
const api = (level: number) =>
  `https://raw.githubusercontent.com/reimiii/kdwa-indonesia/refs/heads/main/json/${level}.json`;

async function getUrbanVillages(url: string) {
  const res = await fetch(url);
  const data = await res.json() as Region[];
  const result = data.filter((d) => d.type === 'urban village')
  return result;
}

async function main() {
  const urbans = await getUrbanVillages(api(4));
  console.log(`urban: ${urbans.length}`)
}
```

Jalankan dengan Bun:
```bash
bun run example.ts
```

Ganti URL sesuai lokasi file JSON yang ingin diambil.

To update new data run:

```bash
bun geo update
bun geo export
```

---

## Sumber Data

Data wilayah administratif Indonesia dalam proyek ini diperoleh dari repository berikut:

* [cahyadsn/wilayah](https://github.com/cahyadsn/wilayah)

Terima kasih kepada penulis aslinya atas penyediaan dataset.
