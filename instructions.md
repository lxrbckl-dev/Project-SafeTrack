




# Auth GitHub CLI
gh auth login

# Create labels
gh label create "difficulty:trivial" --color "0E8A16"
gh label create "difficulty:routine" --color "1D76DB"
gh label create "difficulty:complex" --color "D93F0B"
gh label create "difficulty:critical" --color "B60205"
gh label create "bug" --color "D73A4A"

# Flutter
cd flutter && flutter pub get && cd ..

# Go
cd backend && go mod tidy && cd ..

# Playwright
cd playwright && npm install && npx playwright install chromium && cd ..

# Reconfigure Firebase for new directory
cd flutter
flutterfire configure --project=project-175f3 --platforms=ios,android,web,macos
cd ..
5. Update paths in agent definitions

The worktree paths in .claude/agents/ reference highlander. These need to match the new repo name:

../highlander-swe1/ → ../NEW-REPO-NAME-swe1/
../highlander-swe2/ → ../NEW-REPO-NAME-swe2/
../highlander-qa/ → ../NEW-REPO-NAME-qa/
6. Initial commit and push


git add -A
git commit -m "Initial commit: full hackathon infrastructure"
git push origin main
7. Verify

docker-compose up — Go + PostgreSQL + Ollama start
cd flutter && flutter build web — Flutter compiles
gh issue list — GitHub CLI works
curl localhost:8000/health — Go API responds
Want me to do the file copy for you once you create the new repo and tell me the name?