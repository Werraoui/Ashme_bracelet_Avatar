# Configuration des emails d'alerte (AVATAR)

## Quand un email part ?

Un email est envoyé **uniquement** si :

1. La mesure est classée **CRITIQUE** (SpO₂ &lt; 92, ou FC &gt; 120, ou FR &gt; 30).
2. Vous avez au moins un **contact « Très proche »** avec une **adresse email**.
3. Le serveur Render a **SMTP configuré** et `NOTIF_DRY_RUN=false`.

Les cas **ATTENTION** créent des alertes en base mais **n'envoient pas d'email**.

## Variables sur Render (obligatoires)

| Variable | Exemple |
|----------|---------|
| `SMTP_HOST` | `smtp.gmail.com` |
| `SMTP_PORT` | `587` |
| `SMTP_USER` | votre Gmail |
| `SMTP_PASS` | mot de passe d'application Gmail (16 caractères) |
| `SMTP_FROM` | même adresse que SMTP_USER |
| `SMTP_TLS` | `true` |
| `NOTIF_DRY_RUN` | `false` |
| `PUBLIC_BASE_URL` | `https://ashme-bracelet-avatar.onrender.com` |

### Gmail

1. Activer la validation en 2 étapes sur le compte Google.
2. Créer un **mot de passe d'application** : https://myaccount.google.com/apppasswords
3. Utiliser ce mot de passe dans `SMTP_PASS` (pas le mot de passe du compte).

## Où voir le résultat ?

- **App Flutter** : message après « Analyser IA » (envoyé / échec).
- **Écran Alertes** : statut `sent` ou `failed` + `error_message`.
- **Boîte mail du contact** : objet `AVATAR — Alerte asthme CRITIQUE` (vérifier les **spams**).

## Causes fréquentes « je ne trouve pas le mail »

| Cause | Solution |
|-------|----------|
| Pas de contact « Très proche » avec email | Contacts → relation **Très proche** + email |
| `NOTIF_DRY_RUN=true` sur Render | Mettre `false` et redéployer |
| SMTP non configuré sur Render | Renseigner toutes les variables SMTP_* |
| État ATTENTION seulement | Normal : email seulement pour CRITIQUE |
| Mail dans les spams | Chercher « AVATAR » ou « Alerte asthme » |
