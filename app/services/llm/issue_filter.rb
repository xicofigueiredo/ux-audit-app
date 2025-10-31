# app/services/llm/issue_filter.rb
module Llm
  class IssueFilter
    # Generic phrases that indicate low-quality, vague issues
    GENERIC_PHRASES = [
      'lack of', 'insufficient', 'poor', 'unclear',
      'should have', 'could have', 'missing',
      'no clear', 'not enough', 'limited',
      'inadequate', 'vague', 'ambiguous'
    ].freeze

    # Minimum quality score threshold (0-10 scale)
    DEFAULT_MIN_QUALITY_SCORE = 6

    # Filter out low-quality issues based on quality scoring
    # Returns only issues that meet the minimum quality threshold
    def self.filter(issues, min_quality_score: DEFAULT_MIN_QUALITY_SCORE)
      return [] unless issues.is_a?(Array)
      return issues if issues.empty?

      filtered = issues.select do |issue|
        score = quality_score(issue)
        score >= min_quality_score
      end

      removed_count = issues.size - filtered.size
      if removed_count > 0
        Rails.logger.info(
          "IssueFilter: Filtered out #{removed_count} low-quality issues " \
          "(#{issues.size} → #{filtered.size})"
        )
      end

      filtered
    end

    # Calculate quality score for an issue (0-10 scale)
    # Higher score = higher quality, more specific, more actionable
    def self.quality_score(issue)
      return 0 unless issue.is_a?(Hash)

      score = 10.0  # Start with perfect score

      # Extract fields
      title = issue['painPointTitle'].to_s.downcase
      description = issue['issueDescription'].to_s.downcase
      frame_ref = issue['frameReference'].to_s
      recommendations = issue['recommendations']
      severity = issue['severity'].to_s

      # PENALTIES: Reduce score for low-quality indicators

      # Penalty 1: Generic language in description
      generic_count = GENERIC_PHRASES.count { |phrase| description.include?(phrase) }
      score -= (generic_count * 1.0)  # -1 point per generic phrase

      # Penalty 2: Very short description (likely vague)
      if description.length < 50
        score -= 2.0
      elsif description.length < 100
        score -= 1.0
      end

      # Penalty 3: Missing or vague frame reference
      if frame_ref.empty? || frame_ref.include?('not specified')
        score -= 3.0
      elsif !frame_ref.match?(/frame \d+/i)
        score -= 1.5
      end

      # Penalty 4: Few or no recommendations
      rec_count = recommendations.is_a?(Array) ? recommendations.size : 0
      if rec_count == 0
        score -= 3.0
      elsif rec_count == 1
        score -= 1.5
      end

      # Penalty 5: Low severity with vague description
      # (Likely the AI wasn't confident about the issue)
      if severity == 'Low' && description.length < 80
        score -= 2.0
      end

      # Penalty 6: Very short title (likely not specific)
      if title.length < 15
        score -= 1.0
      end

      # BONUSES: Increase score for high-quality indicators

      # Bonus 1: Specific frame reference with range
      if frame_ref.match?(/frames? \d+(-\d+)?/i)
        score += 1.0
      end

      # Bonus 2: Multiple detailed recommendations
      if rec_count >= 3
        score += 1.5
      elsif rec_count >= 2
        score += 0.5
      end

      # Bonus 3: Detailed description
      if description.length > 150
        score += 1.0
      elsif description.length > 100
        score += 0.5
      end

      # Bonus 4: Has element grounding information
      if issue['elementRef'].is_a?(Hash)
        element_type = issue['elementRef']['type']
        if element_type == 'vision'
          score += 1.5  # High confidence element identification
        elsif element_type == 'unknown' && issue['groundingNotes'].present?
          score += 0.5  # At least explained why grounding is unknown
        end
      end

      # Bonus 5: Mentions specific UI elements
      ui_elements = ['button', 'input', 'field', 'menu', 'dropdown', 'icon', 'label', 'form', 'link', 'checkbox', 'radio']
      if ui_elements.any? { |element| description.include?(element) }
        score += 1.0
      end

      # Ensure score is within 0-10 range
      [[score, 0].max, 10].min
    end

    # Group issues by similarity and return best one from each group
    # Useful for deduplication
    def self.deduplicate_similar(issues)
      return [] unless issues.is_a?(Array)
      return issues if issues.size <= 1

      groups = []

      issues.each do |issue|
        # Find if this issue is similar to any existing group
        similar_group = groups.find do |group|
          similarity = calculate_similarity(issue, group.first)
          similarity > 0.6  # 60% similarity threshold
        end

        if similar_group
          # Add to existing group
          similar_group << issue
        else
          # Create new group
          groups << [issue]
        end
      end

      # From each group, pick the highest quality issue
      deduplicated = groups.map do |group|
        group.max_by { |issue| quality_score(issue) }
      end

      removed_count = issues.size - deduplicated.size
      if removed_count > 0
        Rails.logger.info(
          "IssueFilter: Deduplicated #{removed_count} similar issues " \
          "(#{issues.size} → #{deduplicated.size})"
        )
      end

      deduplicated
    end

    private

    # Calculate similarity between two issues (0.0 - 1.0)
    # Based on title and description text similarity
    def self.calculate_similarity(issue1, issue2)
      title1 = issue1['painPointTitle'].to_s.downcase.split
      title2 = issue2['painPointTitle'].to_s.downcase.split

      desc1 = issue1['issueDescription'].to_s.downcase.split
      desc2 = issue2['issueDescription'].to_s.downcase.split

      # Jaccard similarity for titles (weighted more)
      title_similarity = jaccard_similarity(title1, title2)

      # Jaccard similarity for descriptions
      desc_similarity = jaccard_similarity(desc1, desc2)

      # Weighted average (titles matter more for similarity)
      (title_similarity * 0.7) + (desc_similarity * 0.3)
    end

    # Jaccard similarity coefficient
    def self.jaccard_similarity(set1, set2)
      return 0.0 if set1.empty? && set2.empty?
      return 0.0 if set1.empty? || set2.empty?

      intersection = (set1 & set2).size.to_f
      union = (set1 | set2).size.to_f

      intersection / union
    end
  end
end
