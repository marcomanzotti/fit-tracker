package com.fittracker.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.fittracker.android.ui.theme.AppTheme
import com.fittracker.android.ui.theme.Fonts

@Composable
fun Card(
    accent: Color? = null,
    bg: Color = AppTheme.colors.c1,
    content: @Composable ColumnScope.() -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppTheme.radius))
            .background(bg)
            .border(1.dp, AppTheme.colors.brd, RoundedCornerShape(AppTheme.radius))
    ) {
        if (accent != null) {
            Box(
                modifier = Modifier
                    .width(3.dp)
                    .fillMaxHeight()
                    .background(accent)
                    .align(Alignment.CenterStart)
            )
        }
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 15.dp, horizontal = 16.dp),
            content = content
        )
    }
}

@Composable
fun Lbl(text: String, color: Color = AppTheme.colors.sub) {
    Text(
        text = text.uppercase(),
        style = Fonts.head(10, FontWeight.SemiBold),
        color = color
    )
}

@Composable
fun StatTile(
    label: String,
    value: String,
    unit: String? = null,
    valueColor: Color = AppTheme.colors.txt,
    note: String? = null,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppTheme.radiusS))
            .background(AppTheme.colors.c2)
            .border(1.dp, AppTheme.colors.brd, RoundedCornerShape(AppTheme.radiusS))
            .padding(vertical = 13.dp, horizontal = 12.dp)
    ) {
        Text(
            text = label.uppercase(),
            style = Fonts.head(10, FontWeight.SemiBold),
            color = AppTheme.colors.sub,
            maxLines = 1
        )
        Spacer(modifier = Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = value,
                style = Fonts.num(30),
                color = valueColor,
                maxLines = 1
            )
            if (unit != null) {
                Spacer(modifier = Modifier.width(2.dp))
                Text(
                    text = unit,
                    style = Fonts.num(11, FontWeight.SemiBold),
                    color = AppTheme.colors.sub
                )
            }
        }
        if (note != null) {
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = note,
                style = Fonts.num(10),
                color = AppTheme.colors.sub,
                maxLines = 2
            )
        }
    }
}

@Composable
fun FilledButton(title: String, color: Color = AppTheme.colors.acc, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 46.dp)
            .clip(RoundedCornerShape(AppTheme.radiusS))
            .background(color)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = title,
            style = Fonts.num(13, FontWeight.Bold),
            color = AppTheme.colors.bg
        )
    }
}

@Composable
fun GhostButton(title: String, color: Color = AppTheme.colors.sub, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .heightIn(min = 38.dp)
            .clip(RoundedCornerShape(9.dp))
            .background(AppTheme.colors.c2)
            .border(1.dp, AppTheme.colors.brd, RoundedCornerShape(9.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp, horizontal = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = title,
            style = Fonts.num(12, FontWeight.SemiBold),
            color = color
        )
    }
}
