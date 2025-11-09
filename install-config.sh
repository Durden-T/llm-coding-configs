#!/usr/bin/env bash
set -euo pipefail

# === 基础设置 ===
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_ROOT="$HOME/config_backup"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
BACKUP_CREATED="false"
DRY_RUN="false"
MODULES=()

# === 错误处理 ===
cleanup_on_error() {
  echo "❌ 安装失败，正在清理..."
  echo "错误发生在第 ${BASH_LINENO[1]} 行"
  exit 1
}
trap cleanup_on_error ERR

usage() {
  cat <<EOF
用法: $0 [选项] <模块1> [模块2] ...
例如: $0 backend

选项:
  -n, --dry-run    仅显示将要执行的操作，不实际执行
  -l, --list       列出所有可用模块并退出
  -h, --help       显示此帮助信息并退出

脚本行为:
 - 为每个模块下的 package（子目录，例如 claude/）创建软链接到 \$HOME
 - 如果模块中存在 copy_only 文件夹，会直接复制其内容到根目录
 - 若已有冲突文件，会自动备份到 $BACKUP_ROOT/<timestamp>/，保留目录层级
 - 安装完成后自动验证链接是否生效

EOF
  echo "可用模块："
  find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -type d -not -name '.git' -not -name '.claude' -not -name '.internal' -printf '  %f\n'
  exit 0
}

# === 解析命令行选项 ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN="true"
      shift
      ;;
    -l|--list)
      echo "可用模块："
      find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -type d -not -name '.git' -not -name 'internal' -printf '  %f\n'
      exit 0
      ;;
    -h|--help)
      usage
      ;;
    -*)
      echo "❌ 未知选项: $1"
      echo "使用 -h 或 --help 查看帮助"
      exit 1
      ;;
    *)
      MODULES+=("$1")
      shift
      ;;
  esac
done

if [ ${#MODULES[@]} -eq 0 ]; then
  echo "❌ 请指定至少一个模块。"
  usage
fi

# 确保 stow 已安装
if ! command -v stow >/dev/null 2>&1; then
  echo "❌ 未找到 stow，请先安装。"
  echo "  Ubuntu/Debian: sudo apt install stow"
  echo "  macOS: brew install stow"
  exit 1
fi

if [ "$DRY_RUN" = "true" ]; then
  echo "🔍 干运行模式 - 仅显示操作，不实际执行"
  echo
fi

# === 函数 ===

# 处理 copy_only 文件夹 - 直接复制到根目录
handle_copy_only() {
  local module_path="$1"
  local copy_only_path="$module_path/copy_only"

  if [ ! -d "$copy_only_path" ]; then
    return 0
  fi

  echo "  📋 发现 copy_only 文件夹，将直接复制到根目录"

  if [ "$DRY_RUN" = "true" ]; then
    echo "    [dry-run] 将复制 copy_only 内容到: $HOME/"
    # 显示将要复制的文件和目录
    while IFS= read -r -d '' item; do
      rel="${item#$copy_only_path/}"
      target="$HOME/$rel"
      if [ -e "$target" ]; then
        echo "      - $rel (已存在，将跳过)"
      else
        echo "      - $rel"
      fi
    done < <(find "$copy_only_path" -mindepth 1 -print0)
    return 0
  fi

  # 检查并统计目标文件
  local existing_count=0
  local new_count=0
  local to_copy=()

  while IFS= read -r -d '' item; do
    rel="${item#$copy_only_path/}"

    # 忽略 .gitignore 文件
    if [[ "$rel" == ".gitignore" ]]; then
      continue
    fi

    target="$HOME/$rel"

    if [ -e "$target" ] || [ -L "$target" ]; then
      ((existing_count++))
    else
      ((new_count++))
      to_copy+=("$item")
    fi
  done < <(find "$copy_only_path" -mindepth 1 \( -type f -o -type d \) -print0)

  if [ $existing_count -gt 0 ]; then
    echo "    ℹ️  发现 $existing_count 个已存在的文件/目录，将跳过不覆盖"
  fi

  if [ $new_count -eq 0 ]; then
    echo "    ✓ 所有 copy_only 内容已存在，无需复制"
    return 0
  fi

  # 执行复制操作（只复制不存在的文件）
  for item in "${to_copy[@]}"; do
    rel="${item#$copy_only_path/}"
    target="$HOME/$rel"

    # 再次检查目标是否真的不存在（防止竞争条件）
    if [ -e "$target" ] || [ -L "$target" ]; then
      echo "    ⚠️  跳过已存在的文件: $rel"
      continue
    fi

    # 使用更安全的方法复制
    if [ -d "$item" ]; then
      # 对于目录，先创建目录，然后逐个复制文件
      if mkdir -p "$target" 2>/dev/null; then
        # 复制所有新文件到目录
        while IFS= read -r -d '' file; do
          local sub_rel="${file#$item/}"
          local sub_target="$target/$sub_rel"
          local sub_target_dir="$(dirname "$sub_target")"

          # 确保目标子目录存在
          if [ ! -d "$sub_target_dir" ]; then
            mkdir -p "$sub_target_dir" || {
              echo "    ❌ 创建子目录失败: $sub_rel"
              continue
            }
          fi

          # 只复制文件（跳过已存在的）
          if [ -f "$file" ] || [ -L "$file" ]; then
            if [ ! -e "$sub_target" ] && [ ! -L "$sub_target" ]; then
              if cp -f "$file" "$sub_target" 2>/dev/null; then
                : # 成功复制，不输出
              else
                echo "    ❌ 复制文件失败: $sub_rel"
              fi
            fi
          fi
        done < <(find "$item" -mindepth 1 \( -type f -o -type l \) -print0)

        echo "    ✓ 已复制: $rel"
      else
        echo "    ❌ 创建目录失败: $rel"
      fi
    else
      # 对于文件，直接复制
      local target_dir="$(dirname "$target")"
      if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir" || {
          echo "    ❌ 创建目录失败: $target_dir"
          continue
        }
      fi

      if cp -f "$item" "$target" 2>/dev/null; then
        echo "    ✓ 已复制: $rel"
      else
        echo "    ❌ 复制失败: $rel"
      fi
    fi
  done

  echo "    ✓ copy_only 新内容复制完成 ($new_count 个文件/目录)"
  return 0
}

# 备份可能冲突的目标文件或目录（保持原有目录结构）
backup_target() {
  local target="$1"
  local rel_path="${target/#$HOME\//}"   # 去掉 $HOME/ 前缀
  local dest_dir="$BACKUP_ROOT/$TIMESTAMP/$(dirname "$rel_path")"
  local actual_target="$target"

  # 验证模块名防止路径遍历
  if [[ "$rel_path" == *..* ]] || [[ "$rel_path" == \\* ]] || [[ "$rel_path" == /* ]]; then
    echo "    ❌ 目标路径无效: $target"
    return 1
  fi

  # 检查目标是否存在
  if [ ! -e "$target" ]; then
    echo "    ℹ️  目标文件不存在: $target"
    return 0
  fi

  # 如果是符号链接，解析到实际目标
  if [ -L "$target" ]; then
    actual_target="$(readlink -f "$target")"
    echo "    ℹ️  解析符号链接: $target -> $actual_target"
  fi

  # 创建备份目录
  if ! mkdir -p "$dest_dir" 2>/dev/null; then
    echo "    ❌ 无法创建备份目录: $dest_dir"
    return 1
  fi

  # 执行备份
  if [ "$DRY_RUN" = "true" ]; then
    echo "    [dry-run] 将备份: $target -> $dest_dir/"
  else
    # 先复制内容到备份目录
    if ! cp -r "$actual_target" "$dest_dir/" 2>/dev/null; then
      echo "    ❌ 备份失败: $target"
      return 1
    fi
    # 再删除原文件，确保 stow 能正确创建链接
    if ! rm -rf "$target" 2>/dev/null; then
      echo "    ❌ 删除原文件失败: $target"
      return 1
    fi
    echo "    🗂️ 备份完成: $target -> $dest_dir/"
  fi

  BACKUP_CREATED="true"
  return 0
}

# 检查每个包中哪些文件会与现有目标冲突，并备份
prepare_package() {
  local module_path="$1"
  local pkg="$2"
  local pkg_path="$module_path/$pkg"

  if [ ! -d "$pkg_path" ]; then
    return 0
  fi

  # 验证包名
  if [[ "$pkg" == *..* ]] || [[ "$pkg" == \\* ]] || [[ "$pkg" == /* ]]; then
    echo "    ❌ 无效的包名: $pkg"
    return 1
  fi

  # 只检查顶级项目和目录（stow 只会为这些创建符号链接）
  local count=0
  while IFS= read -r -d '' file; do
    # 计算相对路径
    rel="${file#$pkg_path/}"

    # 只处理顶级项目（不包含斜杠的路径）
    if [[ "$rel" == */* ]]; then
      continue
    fi

    # 忽略 .gitignore 文件
    if [[ "$rel" == ".gitignore" ]]; then
      continue
    fi

    target="$HOME/$rel"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
      if backup_target "$target"; then
        ((count++))
      fi
    fi
  done < <(find "$pkg_path" -mindepth 1 \( -type f -o -type d \) -print0 | sort)

  if [ $count -gt 0 ]; then
    echo "    📦 已备份 $count 个冲突文件/目录"
  fi

  return 0
}

# 验证符号链接是否正确创建
verify_symlinks() {
  local pkg_path="$1"
  local pkg="$2"
  local success=true

  # stow 创建的是顶级文件和目录的符号链接
  # 只检查顶级项目，不递归检查子文件和子目录
  while IFS= read -r -d '' file; do
    # 计算相对路径
    rel="${file#$pkg_path/}"

    # 只检查顶级项目（不包含斜杠的路径）
    if [[ "$rel" == */* ]]; then
      continue
    fi

    # 忽略 .gitignore 文件
    if [[ "$rel" == ".gitignore" ]]; then
      continue
    fi

    target="$HOME/$rel"
    link_target="$(readlink "$target" 2>/dev/null || echo "")"

    if [ -L "$target" ]; then
      # 检查链接是否有效
      if [ -e "$target" ]; then
        echo "    ✓ 验证成功: $rel"
      else
        echo "    ❌ 链接损坏: $rel -> $link_target"
        success=false
      fi
    else
      echo "    ⚠️  未创建链接: $rel"
      success=false
    fi
  done < <(find "$pkg_path" -mindepth 1 \( -type f -o -type d \) -print0 | sort)

  if [ "$success" = true ]; then
    return 0
  else
    return 1
  fi
}

# === 主流程 ===
TOTAL_MODULES=${#MODULES[@]}
CURRENT_MODULE=0

for MODULE in "${MODULES[@]}"; do
  CURRENT_MODULE=$((CURRENT_MODULE + 1))

  # 验证模块名防止路径遍历
  if [[ "$MODULE" == *..* ]] || [[ "$MODULE" == \\* ]] || [[ "$MODULE" == /* ]]; then
    echo "❌ 无效的模块名: $MODULE"
    exit 1
  fi

  MODULE_PATH="$DOTFILES_DIR/$MODULE"
  if [ ! -d "$MODULE_PATH" ]; then
    echo "⚠️ 模块不存在: $MODULE"
    echo "使用 -l 或 --list 查看可用模块"
    continue
  fi

  echo "[$CURRENT_MODULE/$TOTAL_MODULES] 🚀 正在安装模块: $MODULE"
  echo

  # 首先处理 copy_only 文件夹（如果有的话）
  if ! handle_copy_only "$MODULE_PATH"; then
    echo "  ⚠️ copy_only 处理失败，但将继续处理其他内容"
  fi
  echo

  shopt -s nullglob
  for pkgdir in "$MODULE_PATH"/*/; do
    [ -d "$pkgdir" ] || continue
    pkg="$(basename "$pkgdir")"

    # 跳过 copy_only 目录，它已经由 handle_copy_only() 处理
    if [ "$pkg" = "copy_only" ]; then
      continue
    fi

    echo "  → 处理 package: $pkg"

    # 准备和备份
    if ! prepare_package "$MODULE_PATH" "$pkg"; then
      echo "    ❌ 准备包 $pkg 失败"
      continue
    fi

    # 执行 stow
    if [ "$DRY_RUN" = "true" ]; then
      echo "    [dry-run] 将执行: stow -v -d \"$MODULE_PATH\" -t \"$HOME\" \"$pkg\""
    else
      echo "    📦 正在创建符号链接..."
      if ! stow -v -d "$MODULE_PATH" -t "$HOME" "$pkg"; then
        echo "    ❌ Stow 失败，包: $pkg"
        exit 1
      fi
      echo "    ✓ 符号链接创建完成"
    fi

    # 验证 symlinks
    if [ "$DRY_RUN" != "true" ]; then
      echo "  验证 symlinks..."
      if verify_symlinks "$MODULE_PATH/$pkg" "$pkg"; then
        echo "  ✓ 包 $pkg 验证通过"
      else
        echo "  ⚠️ 包 $pkg 验证发现问题"
      fi
    fi
    echo
  done
  shopt -u nullglob

  echo "✅ 模块 $MODULE 安装完成"
  echo
done

echo "═══════════════════════════════════════════"
if [ "$BACKUP_CREATED" = "true" ]; then
  echo "🎉 安装完成！"
  echo ""
  echo "备份文件位于: $BACKUP_ROOT/$TIMESTAMP"
  echo "如需恢复，请手动将备份中的文件复制回原位置"
else
  echo "🎉 完成。"
fi

if [ "$DRY_RUN" = "true" ]; then
  echo ""
  echo "这是干运行模式，未实际执行任何操作"
  echo "如需实际执行，请重新运行不带 -n 选项的命令"
fi

