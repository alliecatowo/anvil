import SwiftUI

// MARK: - Models

struct SearchMatch: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let lineContent: String
    let matchRange: Range<String.Index>

    var matchText: String {
        String(lineContent[matchRange])
    }
}

struct FileSearchResult: Identifiable {
    let id = UUID()
    let filePath: String
    let fileName: String
    let matches: [SearchMatch]
}

// MARK: - ViewModel

@MainActor
class ProjectSearchViewModel: ObservableObject {
    @Published var searchText: String = "" {
        didSet { searchIfNeeded() }
    }
    @Published var replaceText: String = ""
    @Published var matchCase: Bool = false {
        didSet { searchIfNeeded() }
    }
    @Published var useRegex: Bool = false {
        didSet { searchIfNeeded() }
    }
    @Published var wholeWord: Bool = false {
        didSet { searchIfNeeded() }
    }
    @Published var fileFilter: String = "" {
        didSet { searchIfNeeded() }
    }
    @Published var isReplaceExpanded: Bool = false
    @Published var results: [FileSearchResult] = []
    @Published var isSearching: Bool = false
    @Published var collapsedFiles: Set<String> = []

    var totalMatchCount: Int {
        results.reduce(0) { $0 + $1.matches.count }
    }

    var fileCount: Int {
        results.count
    }

    private var searchTask: Task<Void, Never>?

    private func searchIfNeeded() {
        searchTask?.cancel()
        guard searchText.count >= 2 else {
            results = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch()
        }
    }

    func performSearch() async {
        guard !searchText.isEmpty else {
            results = []
            return
        }
        isSearching = true
        defer { isSearching = false }

        // Build sample results to demonstrate the UI
        // In production this would walk the project file tree
        let sampleFiles = sampleProjectFiles()
        var newResults: [FileSearchResult] = []

        for (path, content) in sampleFiles {
            if Task.isCancelled { return }

            // Apply file filter
            if !fileFilter.isEmpty {
                let patterns = fileFilter.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                let matchesFilter = patterns.contains { pattern in
                    if pattern.hasPrefix("*.") {
                        let ext = String(pattern.dropFirst(2))
                        return path.hasSuffix(".\(ext)")
                    }
                    return path.contains(pattern)
                }
                if !matchesFilter { continue }
            }

            let lines = content.components(separatedBy: "\n")
            var matches: [SearchMatch] = []

            for (index, line) in lines.enumerated() {
                let ranges = findMatchRanges(in: line)
                for range in ranges {
                    matches.append(SearchMatch(
                        lineNumber: index + 1,
                        lineContent: line,
                        matchRange: range
                    ))
                }
            }

            if !matches.isEmpty {
                let fileName = (path as NSString).lastPathComponent
                newResults.append(FileSearchResult(
                    filePath: path,
                    fileName: fileName,
                    matches: matches
                ))
            }
        }

        results = newResults
    }

    private func findMatchRanges(in line: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []

        if useRegex {
            var options: NSRegularExpression.Options = []
            if !matchCase { options.insert(.caseInsensitive) }
            guard let regex = try? NSRegularExpression(pattern: searchText, options: options) else {
                return []
            }
            let nsRange = NSRange(line.startIndex..., in: line)
            let nsMatches = regex.matches(in: line, range: nsRange)
            for m in nsMatches {
                if let range = Range(m.range, in: line) {
                    ranges.append(range)
                }
            }
        } else {
            let searchIn = matchCase ? line : line.lowercased()
            let searchFor = matchCase ? searchText : searchText.lowercased()

            var startIndex = searchIn.startIndex
            while let range = searchIn.range(of: searchFor, range: startIndex..<searchIn.endIndex) {
                // Whole word check
                if wholeWord {
                    let before = range.lowerBound == searchIn.startIndex
                        || !searchIn[searchIn.index(before: range.lowerBound)].isLetter
                    let after = range.upperBound == searchIn.endIndex
                        || !searchIn[range.upperBound].isLetter
                    if !before || !after {
                        startIndex = range.upperBound
                        continue
                    }
                }
                // Map back to original line indices
                let offset = searchIn.distance(from: searchIn.startIndex, to: range.lowerBound)
                let length = searchIn.distance(from: range.lowerBound, to: range.upperBound)
                let origStart = line.index(line.startIndex, offsetBy: offset)
                let origEnd = line.index(origStart, offsetBy: length)
                ranges.append(origStart..<origEnd)
                startIndex = range.upperBound
            }
        }

        return ranges
    }

    func toggleFileCollapsed(_ filePath: String) {
        if collapsedFiles.contains(filePath) {
            collapsedFiles.remove(filePath)
        } else {
            collapsedFiles.insert(filePath)
        }
    }

    func replaceAllInFile(_ filePath: String) {
        // In production: read file, replace all matches, write back
        // For now, remove from results to show feedback
        results.removeAll { $0.filePath == filePath }
    }

    func replaceAll() {
        // In production: iterate all files and replace
        results.removeAll()
    }

    func clear() {
        searchText = ""
        replaceText = ""
        results = []
        collapsedFiles = []
    }

    // MARK: - Sample Data

    private func sampleProjectFiles() -> [(String, String)] {
        [
            ("src/auth/handler.ts", """
            import { Request, Response } from 'express';
            import { validateToken } from './token';

            export async function handleLogin(req: Request, res: Response) {
                const { email, password } = req.body;
                const user = await findUser(email);
                if (!user) {
                    return res.status(401).json({ error: 'Invalid credentials' });
                }
                const token = generateToken(user);
                res.json({ token, user: { id: user.id, email: user.email } });
            }

            export async function handleLogout(req: Request, res: Response) {
                const token = req.headers.authorization?.split(' ')[1];
                if (token) {
                    await revokeToken(token);
                }
                res.status(204).send();
            }
            """),
            ("src/auth/token.ts", """
            import jwt from 'jsonwebtoken';
            import { User } from '../models/user';

            const SECRET = process.env.JWT_SECRET || 'dev-secret';

            export function generateToken(user: User): string {
                return jwt.sign({ userId: user.id, email: user.email }, SECRET, {
                    expiresIn: '24h',
                });
            }

            export function validateToken(token: string): boolean {
                try {
                    jwt.verify(token, SECRET);
                    return true;
                } catch {
                    return false;
                }
            }
            """),
            ("src/models/user.ts", """
            export interface User {
                id: string;
                email: string;
                name: string;
                createdAt: Date;
                updatedAt: Date;
            }

            export interface UserProfile extends User {
                avatar?: string;
                bio?: string;
                settings: UserSettings;
            }

            export interface UserSettings {
                theme: 'light' | 'dark' | 'system';
                notifications: boolean;
                email: string;
            }
            """),
            ("src/api/routes.ts", """
            import { Router } from 'express';
            import { handleLogin, handleLogout } from '../auth/handler';
            import { authMiddleware } from '../middleware/auth';

            const router = Router();

            router.post('/login', handleLogin);
            router.post('/logout', authMiddleware, handleLogout);
            router.get('/profile', authMiddleware, getProfile);
            router.put('/profile', authMiddleware, updateProfile);

            export default router;
            """),
            ("src/middleware/auth.ts", """
            import { Request, Response, NextFunction } from 'express';
            import { validateToken } from '../auth/token';

            export function authMiddleware(req: Request, res: Response, next: NextFunction) {
                const token = req.headers.authorization?.split(' ')[1];
                if (!token || !validateToken(token)) {
                    return res.status(401).json({ error: 'Unauthorized' });
                }
                next();
            }
            """),
            ("README.md", """
            # Project

            A sample web application with authentication.

            ## Setup

            ```bash
            npm install
            npm run dev
            ```

            ## Architecture

            - `src/auth/` — Authentication handlers and token management
            - `src/api/` — API route definitions
            - `src/middleware/` — Express middleware (auth, logging, etc.)
            - `src/models/` — Data models and interfaces
            """),
        ]
    }
}
