# lib-apply.ps1 - renders kit templates into an instance (init and apply share this engine).
# Depends on lib-render.ps1 being dot-sourced first. NEVER deletes files; existing
# targets are skipped unless -Force.

function Get-RoleSkills {
    param([hashtable]$Cfg, [string]$Role, [string[]]$Computed)
    # project.yaml is the authority for skill allow-lists. The kit ships none: shared skills, the
    # per-role declarations, and any grants the integrations imply are unioned here, in that order,
    # with blanks and duplicates removed. validate-harness.ps1 fails any agent that allows a skill
    # this list does not contain, so the declaration is the enforcement point, not a suggestion.
    $list = @()
    $list += @($Cfg['skills.shared'])
    $list += @($Cfg["skills.$Role"])
    $list += @($Computed)
    return @($list | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
}

function Get-RoleSkillGrants {
    param([hashtable]$Cfg)
    # THE authority on which skills each role may load. The renderer writes these into the agent
    # files and validate-harness.ps1 recomputes the same map to check them, so a skill can never be
    # granted in one place and merely asserted in another. project.yaml is authoritative for the
    # declared lists; only integration/stack-derived grants are computed here.
    $dsTools = ("$($Cfg['integrations.design_system_tools'])" -eq 'true')
    $liveBr  = ("$($Cfg['integrations.browser_live'])" -eq 'true')

    $computed = @{}
    $computed['project-manager']  = @()
    $computed['business-analyst'] = @()
    $designerExtra = @('prototype', 'writing-for-agents')
    if ($dsTools) { $designerExtra = @('hallmark', 'impeccable') + $designerExtra }
    if ($liveBr)  { $designerExtra += 'browseros-neo' }
    $computed['designer'] = $designerExtra
    $computed['developer'] = @($Cfg['stack.agent_skills'])
    $qaExtra = @()
    if ($liveBr) { $qaExtra = @('browseros-neo') }
    $computed['qa-engineer'] = $qaExtra
    $computed['code-reviewer'] = @()
    $computed['security-monitor'] = @()

    $grants = @{}
    foreach ($role in $computed.Keys) { $grants[$role] = @(Get-RoleSkills -Cfg $Cfg -Role $role -Computed @($computed[$role])) }
    return $grants
}

function New-RenderSlots { param([hashtable]$Cfg)
    $slots = @{}
    $dsTools = ("$($Cfg['integrations.design_system_tools'])" -eq 'true')
    $liveBr  = ("$($Cfg['integrations.browser_live'])" -eq 'true')
    $grants = Get-RoleSkillGrants -Cfg $Cfg

    $slots['PM_STACK_SHELL_ALLOWS'] = ''
    $slots['PM_SKILL_ALLOWS'] = New-PermRulesBlock -Action 'skill' -Values @($grants['project-manager']) -Effect 'allow'
    $slots['BA_SKILL_ALLOWS'] = New-PermRulesBlock -Action 'skill' -Values @($grants['business-analyst']) -Effect 'allow'
    $slots['REVIEWER_SKILL_ALLOWS'] = New-PermRulesBlock -Action 'skill' -Values @($grants['code-reviewer']) -Effect 'allow'
    $slots['SECURITY_SKILL_ALLOWS'] = New-PermRulesBlock -Action 'skill' -Values @($grants['security-monitor']) -Effect 'allow'

    $devCmds = @($Cfg['stack.dev_commands'])
    $slots['DEVELOPER_STACK_SHELL_ALLOWS'] = New-PermRulesBlock -Action 'shell' -Values $devCmds -Effect 'allow'
    $slots['DEVELOPER_STACK_SKILL_ALLOWS'] = New-PermRulesBlock -Action 'skill' -Values @($grants['developer']) -Effect 'allow'

    $desShell = ''
    if ($dsTools) {
        $desShell = New-PermRulesBlock -Action 'shell' -Values @('node .agents/skills/hallmark/scripts','npx impeccable audit','npx impeccable critique','npx impeccable polish','npx impeccable layout','npx impeccable typeset') -Effect 'allow'
        $desShell += "`r`n" + (New-PermRulesBlock -Action 'shell' -Values @('npx impeccable document','npx impeccable extract','npx impeccable new-work') -Effect 'deny')
    }
    $slots['DESIGNER_STACK_SHELL_ALLOWS'] = $desShell
    $slots['DESIGNER_SKILL_ALLOWS'] = New-PermRulesBlock -Action 'skill' -Values @($grants['designer']) -Effect 'allow'

    $slots['QA_STACK_SHELL_ALLOWS'] = New-PermRulesBlock -Action 'shell' -Values @($Cfg['stack.qa_commands']) -Effect 'allow'
    $slots['QA_INTEGRATION_SKILL_ALLOWS'] = New-PermRulesBlock -Action 'skill' -Values @($grants['qa-engineer']) -Effect 'allow'

    $slots['REVIEWER_STACK_SHELL_ALLOWS'] = New-PermRulesBlock -Action 'shell' -Values @($Cfg['stack.reviewer_commands']) -Effect 'allow'
    $slots['SECURITY_AUDIT_TOOL_ALLOWS'] = New-PermRulesBlock -Action 'shell' -Values @($Cfg['stack.security_commands']) -Effect 'allow'

    # Application code is denied for edit project-wide; only the Developer re-allows its source dirs.
    $slots['SOURCE_DENY_RULES'] = Get-SourceDenyRules -Cfg $Cfg
    $slots['DEVELOPER_SOURCE_ALLOWS'] = New-PermRulesBlock -Action 'edit' -Values @($Cfg['stack.source_dirs']) -Effect 'allow'

    return $slots
}

function Get-RenderPlan { param([string]$KitDir, [string]$TargetDir, [string]$DocsHarnessPath)
    # Ordered map of kit-relative -> instance-relative.
    # Scope 'instance' = harness-owned generated files (apply may regenerate).
    # Scope 'init'     = project-authored files (only created at initialization; apply must NOT overwrite).
    $plan = New-Object System.Collections.ArrayList
    function AddItem($srcList, [string]$dstPrefix, [string]$stripTmpl, [string]$Scope) {
        foreach ($f in $srcList) {
            $name = Split-Path -Leaf $f
            $dstName = $name
            if ($stripTmpl -and $dstName.EndsWith('.tmpl')) { $dstName = $dstName.Substring(0, $dstName.Length - 5) }
            [void]$plan.Add([pscustomobject]@{ Src = $f; Dst = (Join-Path $TargetDir (Join-Path $dstPrefix $dstName)); Scope = $Scope })
        }
    }
    $k = $KitDir
    AddItem @(Get-ChildItem -File (Join-Path $k 'agents/*.md.tmpl')) '.opencode/agents' $true 'instance'
    AddItem @(Get-ChildItem -File (Join-Path $k 'commands/*.md.tmpl')) '.opencode/commands' $true 'instance'
    AddItem @(Get-ChildItem -File (Join-Path $k 'github/ISSUE_TEMPLATE/*.tmpl')) '.github/ISSUE_TEMPLATE' $true 'instance'
    AddItem @(Get-ChildItem -File (Join-Path $k 'github/workflows/*.tmpl')) '.github/workflows' $true 'instance'
    AddItem @((Join-Path $k 'github/workflows/harness-validation.yml')) '.github/workflows' $false 'instance'
    AddItem @((Join-Path $k 'github/labels.json')) '.github' $false 'instance'
    # Governance files GitHub reads from .github/ directly. These two were absent from the plan,
    # so instances silently lacked the CODEOWNERS review requirement that the GitHub-side controls
    # (negative test G-02) and project-initialization.md both assume exists.
    AddItem @((Join-Path $k 'github/CODEOWNERS.tmpl')) '.github' $true 'instance'
    AddItem @((Join-Path $k 'github/pull_request_template.md.tmpl')) '.github' $true 'instance'
    # docs/project tree (mirror structure; strip .tmpl) - init only
    $docsRoot = Join-Path $k 'docs/project'
    foreach ($f in (Get-ChildItem -File -Recurse $docsRoot)) {
        $rel = $f.FullName.Substring($docsRoot.Length + 1)
        $dstName = $rel
        if ($dstName.EndsWith('.tmpl')) { $dstName = $dstName.Substring(0, $dstName.Length - 5) }
        [void]$plan.Add([pscustomobject]@{ Src = $f.FullName; Dst = (Join-Path $TargetDir (Join-Path 'docs/project' $dstName)); Scope = 'init' })
    }
    # singletons
    [void]$plan.Add([pscustomobject]@{ Src = (Join-Path $k 'AGENTS.md.tmpl');              Dst = (Join-Path $TargetDir 'AGENTS.md');        Scope = 'instance' })
    [void]$plan.Add([pscustomobject]@{ Src = (Join-Path $k 'config/opencode.jsonc.tmpl');  Dst = (Join-Path $TargetDir 'opencode.jsonc');   Scope = 'instance' })
    [void]$plan.Add([pscustomobject]@{ Src = (Join-Path $k 'gitignore.tmpl');              Dst = (Join-Path $TargetDir '.gitignore');      Scope = 'init' })
    [void]$plan.Add([pscustomobject]@{ Src = (Join-Path $k 'README-project.md.tmpl');      Dst = (Join-Path $TargetDir 'README.md');        Scope = 'init' })
    return $plan
}

function Invoke-HarnessRender {
    param(
        [Parameter(Mandatory)][string]$KitDir,
        [Parameter(Mandatory)][string]$ProjectYamlPath,
        [Parameter(Mandatory)][string]$TargetDir,
        [string]$DocsHarnessPath,               # core docs copied on init; omitted on home-repo apply
        [ValidateSet('all','instance')][string]$Scope = 'all',
        [switch]$DryRun,
        [switch]$Force
    )
    $cfgPath = if (Test-Path $ProjectYamlPath) { $ProjectYamlPath } else { throw "project.yaml not found: $ProjectYamlPath" }
    $cfg = Get-ProjectConfig $cfgPath
    $profiles = Join-Path $KitDir 'lifecycle/profiles.yaml'
    $ctx = New-RenderContext -Cfg $cfg -KitDir $KitDir -ProfilesPath $profiles
    $ctx['GIT_REMOTE_URL'] = [string]$cfg['repository.remote']
    $ctx['REPO_DOCS_URL'] = "https://github.com/$($cfg['owner.login'])/$($cfg['project.slug'])/tree/main/docs/project"
    foreach ($kv in (New-RenderSlots $cfg).GetEnumerator()) { $ctx[$kv.Key] = $kv.Value }

    $denyRef = ''; $srvRef = ''
    Get-McpRenderBlocks -Cfg $cfg -DenyOut ([ref]$denyRef) -ServersOut ([ref]$srvRef)
    $stackDeny = Get-StackDenyRules $cfg
    # Join generated rule blocks so the permissions array is always valid JSONC:
    # the MCP block keeps its trailing comma only when the stack block follows.
    if ($stackDeny) {
        $ctx['MCP_DENY_RULES'] = $denyRef
        $ctx['STACK_DENY_RULES'] = $stackDeny
    } else {
        $ctx['MCP_DENY_RULES'] = ($denyRef.TrimEnd((',', "`r", "`n") -join ''))
        $ctx['STACK_DENY_RULES'] = ''
    }
    $ctx['MCP_SERVERS'] = if ($srvRef) { $srvRef } else { '' }
    $ctx['STACK_POLICY_DENY_RULES'] = Get-StackPolicyDenies $cfg
    $ctx['KIT_COMMIT'] = Get-KitCommit -KitDir $KitDir -TargetDir $TargetDir
    $ctx['CI_STACK_STEPS'] = ''
    $ctx['SECURITY_STACK_STEPS'] = ''

    $plan = Get-RenderPlan -KitDir $KitDir -TargetDir $TargetDir
    if ($Scope -eq 'instance') { $plan = @($plan | Where-Object { $_.Scope -eq 'instance' }) }
    $leaks = @(); $created = 0; $skipped = 0; $overwritten = 0
    foreach ($item in $plan) {
        $text = Read-TextRaw $item.Src
        $localLeak = $null
        $rendered = Expand-Template -Text $text -Ctx $ctx -LeakList ([ref]$localLeak)
        if ($localLeak) { $leaks += ("{0}: {1}" -f $item.Dst, ($localLeak -join ', ')) }
        if ($DryRun) { $created++ ; continue }
        if ((Test-Path $item.Dst) -and -not $Force) { $skipped++; Write-Host "SKIP (exists): $($item.Dst)"; continue }
        Write-TextUtf8 -Path $item.Dst -Text $rendered
        if (Test-Path $item.Dst) { $overwritten++ } else { $created++ }
    }
    # optional: copy core harness docs (init only)
    if ($DocsHarnessPath -and (Test-Path $DocsHarnessPath)) {
        foreach ($f in (Get-ChildItem -File -Recurse $DocsHarnessPath)) {
            $rel = $f.FullName.Substring($DocsHarnessPath.Length + 1)
            $dst = Join-Path (Join-Path $TargetDir 'docs/harness') $rel
            if ((Test-Path $dst) -and -not $Force) { $skipped++; continue }
            if (-not $DryRun) {
                $d = Split-Path -Parent $dst
                if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
                Copy-Item $f.FullName $dst -Force
            }
        }
        # copy the kit itself so the instance can re-apply upgrades
        if (-not $DryRun) {
            $srcRoot = Split-Path -Parent $KitDir      # the harness/ directory
            $kitDstRoot = Join-Path $TargetDir 'harness'
            foreach ($part in @('kit','scripts')) {
                $d = Join-Path $kitDstRoot $part
                if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
                Copy-Item -Path (Join-Path $srcRoot "$part/*") -Destination $d -Recurse -Force
            }
            Copy-Item -Path (Join-Path $srcRoot 'HARNESS-VERSION') -Destination (Join-Path $kitDstRoot 'HARNESS-VERSION') -Force
            Copy-Item -Path (Join-Path $srcRoot 'README.md') -Destination (Join-Path $kitDstRoot 'README.md') -Force
        }
    }
    [pscustomobject]@{ Files = $plan.Count; Rendered = if ($DryRun) { $created } else { $created + $overwritten }; Skipped = $skipped; Leaks = $leaks; Commit = $ctx['KIT_COMMIT']; KitVersion = $ctx['KIT_VERSION'] }
}
