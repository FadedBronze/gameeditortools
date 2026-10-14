package parsing

import "core:testing"

find_next :: proc(offset: u32, str: string, search: string) -> u32 {
    i := offset
    j := 0
    start: u32 = 0
    found_match := false
    
    if i >= u32(len(str)) {
        return i
    }

    for true {
        if str[i] == search[j] {
            if !found_match {
                start = i
                found_match = true
            }

            j += 1
        }

        i += 1

        if i >= u32(len(str)) {
            break
        }
        
        if j >= len(search) {
            break
        }

        if str[i] != search[j] {
            if found_match {
                j = 0
                found_match = false
            }
        }
    }

    assert(str[start:start+u32(len(search))] == search, message=str[start:start+u32(len(search))])

    return start
}

@(test)
test_find_next :: proc(t: ^testing.T) {
    str := "the cat is in the bag"
    strhard := "aababbaba"

    testing.expect_value(t, find_next(0, str, "bag"), 18)
    testing.expect_value(t, find_next(0, str, "e c"), 2)
    testing.expect_value(t, find_next(0, str, "the"), 0)
    testing.expect_value(t, find_next(1, str, "the"), 14)
    testing.expect_value(t, find_next(1, strhard, "abb"), 3)
}

skip_over_next :: proc(offset: u32, main_str: string, search: string) -> u32 {
    return find_next(offset, main_str, search) + u32(len(search))
}

// skips to next nonempty line without comment
skip_to_next_line :: proc(offset: u32, main_str: string) -> u32 {
    offset := offset
    offset = skip_over_next(offset, main_str, "\n")
    for offset < u32(len(main_str)) {
        if main_str[offset] == '/' && int(offset+1) < len(main_str) && main_str[offset+1] == '/' {
            offset += 2
        } else if main_str[offset] == '\n' || main_str[offset] == ' ' {
            offset += 1
        } else {
            break;
        }
    }
    return offset
}

skip_spaces :: proc(offset: u32, main_str: string) -> u32 {
    offset := offset
    for offset < u32(len(main_str)) && main_str[offset] == ' ' {
        offset += 1
    }
    return offset
}

skip_spaces_and_newlines :: proc(offset: u32, main_str: string) -> u32 {
    offset := offset
    for offset < u32(len(main_str)) && (main_str[offset] == ' ' || main_str[offset] == '\n') {
        offset += 1
    }
    return offset
}
