# 🗂️ Downloads Organizer

> Sorts your messy Downloads into clean folders — Images, Videos, Docs, Code, Entertainment & more.

---

## 🚀 Steps to Run

**1. Open PowerShell as Administrator**

**2. Allow scripts (one-time only)**
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

**3. Unblock the script**
```powershell
Unblock-File "C:\Users\Windows\Downloads\Organize-Downloads.ps1"
```

**4. Run it!**
```powershell
& "C:\Users\Windows\Downloads\Organize-Downloads.ps1"
```

> ⚠️ Modify the path inside the script (`$basePath`) before running!

---

## 📂 Check Folder Contents
```powershell
Get-ChildItem "C:\Users\Windows\Downloads\New folder"
```

---

## 📦 Folders Created

| Folder | Types |
|--------|-------|
| 🖼️ Images | jpg, png, heic, webp... |
| 🎬 Videos | mp4, mkv, avi... |
| 🎵 Audio | mp3, flac, wav... |
| 📄 Documents | pdf, docx, xlsx... |
| 🗜️ Archives | zip, rar, 7z, iso... |
| ⚙️ Installers | exe, msi, bat... |
| 💻 Code | py, tf, js, yaml... |
| 🎮 Entertainment | Games & movies |
| 📦 Others | Everything else |

---

*🛠️ Shanthosh | Windows 11 | ThinkPad T480s*
